package Canto::Controller::Curs;

use base 'Catalyst::Controller::HTML::FormFu';

=head1 NAME

Canto::Controller::Curs - curs (curation session) controller

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Controller::Curs

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

use Canto::Curs::State qw/:all/;

with 'Canto::Role::MetadataAccess';
with 'Canto::Role::GAFFormatter';
with 'Canto::Curs::Role::GeneResultSet';

use IO::String;
use Clone qw(clone);
use Hash::Merge;
use Carp qw(cluck);

use Canto::Track;
use Canto::Curs::Utils;
use Canto::Curs::MetadataStorer;
use Canto::MailSender;
use Canto::EmailUtil;
use Canto::Curs::State;
use Canto::Util qw(trim);

use constant {
  MESSAGE_FOR_CURATORS_KEY => 'message_for_curators',
};

# actions to execute for each state, undef for special cases
my %state_dispatch = (
  SESSION_CREATED, 'introduction',
  SESSION_ACCEPTED, 'gene_upload',
  CURATION_IN_PROGRESS, undef,
  CURATION_PAUSED, 'curation_paused',
  NEEDS_APPROVAL, 'finished_publication',
  APPROVAL_IN_PROGRESS, undef,
  APPROVED, 'finished_publication',
  EXPORTED, 'session_exported',
);

# used by the tests to find the most recently created annotations
our $_debug_annotation_ids = undef;

has state => (is => 'rw', init_arg => undef,
              isa => 'Canto::Curs::State');

has metadata_storer => (is => 'rw', init_arg => undef,
                        isa => 'Canto::Curs::MetadataStorer');

has curator_manager => (is => 'rw', init_arg => undef,
                        isa => 'Canto::Track::CuratorManager');

=head2 top

 Action to set up stash contents for curs

=cut
sub top : Chained('/') PathPart('curs') CaptureArgs(1)
{
  my ($self, $c, $curs_key) = @_;

  if (!defined $self->state()) {
    $self->state(Canto::Curs::State->new(config => $c->config()));
  }
  if (!defined $self->metadata_storer()) {
    $self->metadata_storer(Canto::Curs::MetadataStorer->new(config => $c->config()));
  }
  if (!defined $self->curator_manager()) {
    $self->curator_manager(Canto::Track::CuratorManager->new(config => $c->config()));
  }

  my $st = $c->stash();

  my $all_sessions = $c->session()->{all_sessions} //= {};

  $st->{curs_key} = $curs_key;
  my $schema = Canto::Curs::get_schema($c);

  if (!defined $schema) {
    $c->forward('not_found');
    $c->detach();
  }

  $st->{schema} = $schema;

  my $path = $c->req->uri()->path();
  $st->{current_path_uri} = $path;

  (my $controller_name = __PACKAGE__) =~ s/.*::(.*)/\L$1/;
  $st->{controller_name} = $controller_name;

  my $root_path = "/$controller_name/$curs_key";
  $st->{curs_root_path} = $root_path;

  my $root_uri = $c->uri_for($root_path);
  $st->{curs_root_uri} = $root_uri;

  my $config = $c->config();

  $st->{annotation_types} = $config->{annotation_types};
  $st->{annotation_type_list} = $config->{annotation_type_list};

  my ($state, $submitter, $gene_count) = $self->state()->get_state($schema);
  my $submitter_email = $submitter->{email_address};
  my $submitter_name = $submitter->{name};

  $st->{state} = $state;

  if ($state eq APPROVAL_IN_PROGRESS) {
    my $approver_name = $self->get_metadata($schema, 'approver_name');
    my $approver_email = $self->get_metadata($schema, 'approver_email');
    $st->{notice} =
      "Session is being checked by $approver_name <$approver_email>";
  }

  $st->{is_admin_session} =
    $self->get_metadata($schema, 'admin_session');

  $st->{instance_organism} = $config->{instance_organism};
  $st->{multi_organism_mode} = !defined $st->{instance_organism};

  my $with_gene_evidence_codes =
    { map { ( $_, 1 ) }
      grep { $config->{evidence_types}->{$_}->{with_gene} } keys %{$config->{evidence_types}} };
  $st->{with_gene_evidence_codes} = $with_gene_evidence_codes;

  my $evidence_by_annotation_type =
    { map { ($_->{name}, $_->{evidence_codes}); } @{$config->{annotation_type_list}} };
  $st->{evidence_by_annotation_type} = $evidence_by_annotation_type;

  # curation_pub_id will be set if we are annotating a particular publication,
  # rather than annotating genes without a publication
  my $pub_id = $self->get_metadata($schema, 'curation_pub_id');
  $st->{pub} = $schema->find_with_type('Pub', $pub_id);

  $all_sessions->{$curs_key} = {
    key => $curs_key,
    pubid => $st->{pub}->uniquename(),
  };

  die "internal error, can't find Pub for pub_id $pub_id"
    if not defined $st->{pub};

  $st->{submitter_email} = $submitter_email;
  $st->{submitter_name} = $submitter_name;

  $st->{message_to_curators} =
    $self->get_metadata($schema, MESSAGE_FOR_CURATORS_KEY);

  # enabled by default and disabled on /session_reassigned page
  $st->{show_curator_in_title} = 1;

  $st->{gene_count} = $self->get_ordered_gene_rs($schema)->count();

  my $use_dispatch = 1;

  if ($state eq APPROVAL_IN_PROGRESS) {
    if ($c->user_exists() && $c->user()->role()->name() eq 'admin') {
      # fall through, use dispatch table
    } else {
      if ($path !~ m!/ro/?$!) {
        $c->detach('finished_publication');
      }
    }
  }

  if ($state eq SESSION_ACCEPTED &&
      $path =~ m:/(gene_upload|edit_genes|confirm_genes|finish_form):) {
    $use_dispatch = 0;
  }
  if (($state eq NEEDS_APPROVAL || $state eq APPROVED) &&
      $path =~ m:/(ro|finish_form|reactivate_session|begin_approval|restart_approval|annotation/zipexport):) {
    $use_dispatch = 0;
  }

  if ($state eq CURATION_PAUSED && $path =~ m:/(restart_curation|ro):) {
    $use_dispatch = 0;
  }

  if ($state eq SESSION_CREATED && $path =~ m:/assign_session:) {
    $use_dispatch = 0;
  }

  if (($state eq SESSION_CREATED ||
       $state eq SESSION_ACCEPTED ||
       $state eq CURATION_IN_PROGRESS ||
       $state eq CURATION_PAUSED) && $path =~ m:/reassign_session|/session_reassigned:) {
    $use_dispatch = 0;
  }

  if ($state eq EXPORTED && $path =~ m|/ro/?$|) {
    $use_dispatch = 0;
  }

  if ($use_dispatch) {
    my $dispatch_dest = $state_dispatch{$state};
    if (defined $dispatch_dest) {
      $c->detach($dispatch_dest);
    }
  }
}

sub _set_genes_in_session
{
  my $c = shift;
  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $genes_rs = $schema->resultset('Gene');
  my $genes_in_session =
    [map {
      my $gene = $_;
      my $gene_proxy = _get_gene_proxy($config, $gene);

      { id => $gene->gene_id(),
        display_name => $gene_proxy->display_name() } } $genes_rs->all()];
  $st->{genes_in_session} = $genes_in_session;
}

sub not_found: Private
{
  my ($self, $c) = @_;
  $c->forward('Canto::Controller::Root', 'default');
}

sub _redirect_and_detach
{
  my ($c, @path_components) = @_;

  if (@path_components) {
    unshift @path_components, '';
  }

  my $target = $c->stash->{curs_root_uri} . join ('/', @path_components);

  $c->res->redirect($target);
  $c->detach();
}

sub _redirect_to_top_and_detach
{
  my $c = shift;

  my $instance_top_uri = $c->uri_for('/');

  $c->res->redirect($instance_top_uri);
  $c->detach();
}

sub front : Chained('top') PathPart('') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  my $pub_uniquename = $st->{pub}->uniquename();
  $st->{title} = "$pub_uniquename summary";
  # use only in header, not in body:
  $st->{show_title} = 1;
  $st->{template} = 'curs/front.mhtml';

  my $schema = $st->{schema};

  my $total_annotation_count = $schema->resultset('Annotation')->count();

  $st->{total_annotation_count} = $total_annotation_count;

  if ($st->{state} eq APPROVAL_IN_PROGRESS) {
    my $no_annotation_reason =
      $self->get_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY());

    if (defined $no_annotation_reason) {
      push @{$st->{message}}, "Reason given for no annotation: $no_annotation_reason";
    }
  }
}

=head2 read_only_summary

 This action show the summary in readonly mode.

=cut

sub read_only_summary : Chained('top') PathPart('ro') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  my $pub_uniquename = $st->{pub}->uniquename();
  $st->{title} = "Reviewing session for $pub_uniquename";

  # use only in header, not in body:
  $st->{show_title} = 1;
  $st->{read_only_curs} = 1;
  $st->{template} = 'curs/front.mhtml';

  if ($st->{state} eq EXPORTED) {
    $st->{message} =
      ["Review only - this session has been exported so no changes are possible"];
  } else {
    $st->{message} =
      ["Review only - this session has been submitted for approval so no changes are possible"];
  }

  my $schema = $c->stash()->{schema};

  my $no_annotation_reason =
    $self->get_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY());

  if (defined $no_annotation_reason) {
    push @{$st->{message}}, "Reason given for no annotation: $no_annotation_reason";
  }

  my $total_annotation_count = $schema->resultset('Annotation')->count();

  $st->{total_annotation_count} = $total_annotation_count;
}

sub introduction : Private
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $config = $c->config();

  $st->{title} = 'Welcome to ' . $config->{name};
  if (defined $config->{database_name}) {
    $st->{title} .= ' at ' . $config->{database_name};
  }
  $st->{show_title} = 0;
  $st->{template} = 'curs/introduction.mhtml';
}

sub store_statuses : Chained('top') Args(0) Form
{
  my $self = shift;
  my ($c) = @_;

  $self->state()->store_statuses($c->stash()->{schema});
}

my $gene_list_textarea_name = 'gene_identifiers';

# return a list of only those genes which aren't already in the database
sub _filter_existing_genes
{
  my $self = shift;
  my $schema = shift;
  my @genes = @_;

  my @gene_primary_identifiers = map { $_->{primary_identifier} } @genes;

  my $gene_rs = $self->get_ordered_gene_rs($schema);
  my $rs = $gene_rs->search({
    primary_identifier => {
      -in => [@gene_primary_identifiers],
    }
  });

  my %found_genes = ();
  while (defined (my $gene = $rs->next())) {
    $found_genes{$gene->primary_identifier()} = 1;
  }

  return grep { !exists $found_genes{ $_->{primary_identifier} } } @genes;
}

# create genes in the Curs database from a lookup() result
sub _create_genes
{
  my $self = shift;
  my $schema = shift;
  my $result = shift;

  my %ret = ();

  my $_create_curs_genes = sub
      {
        my @genes = @{$result->{found}};

        @genes = $self->_filter_existing_genes($schema, @genes);

        for my $gene (@genes) {
          my $org_full_name = $gene->{organism_full_name};
          my $org_taxonid = $gene->{organism_taxonid};
          my $curs_org =
            Canto::CursDB::Organism::get_organism($schema, $org_full_name,
                                                   $org_taxonid);

          my $primary_identifier = $gene->{primary_identifier};

          my $new_gene = $schema->create_with_type('Gene', {
            primary_identifier => $primary_identifier,
            organism => $curs_org
          });

          $ret{$primary_identifier} = $new_gene
        }
      };

  $schema->txn_do($_create_curs_genes);

  return %ret;
}

sub _find_and_create_genes
{
  my ($self, $schema, $config, $search_terms_ref, $create_when_missing) = @_;

  my @search_terms = @$search_terms_ref;
  my $adaptor = Canto::Track::get_adaptor($config, 'gene');

  my $result;

  if (exists $config->{instance_organism}) {
    $result = $adaptor->lookup(
      {
        search_organism => {
          genus => $config->{instance_organism}->{genus},
          species => $config->{instance_organism}->{species},
        }
      },
      [@search_terms]);
  } else {
    $result = $adaptor->lookup([@search_terms]);
  }


  my %identifiers_matching_more_than_once = ();
  my %genes_matched_more_than_once = ();

  map {
    my $match = $_;
    my $primary_identifier = $match->{primary_identifier};
    map {
      my $identifier = $_;
      $identifiers_matching_more_than_once{$identifier}->{$primary_identifier} = 1;
      $genes_matched_more_than_once{$primary_identifier}->{$identifier} = 1;
    } (@{$match->{match_types}->{synonym} // []},
       $match->{match_types}->{primary_identifier} // (),
       $match->{match_types}->{primary_name} // ());
  } @{$result->{found}};

  sub _remove_single_matches {
    my $hash = shift;
    map {
      my $identifier = $_;

      if (keys %{$hash->{$identifier}} == 1) {
        delete $hash->{$identifier};
      } else {
        $hash->{$identifier} = [sort keys %{$hash->{$identifier}}];
      }
    } keys %$hash;
  }

  _remove_single_matches(\%identifiers_matching_more_than_once);
  _remove_single_matches(\%genes_matched_more_than_once);

  if (@{$result->{missing}} || keys %identifiers_matching_more_than_once > 0 ||
      keys %genes_matched_more_than_once > 0) {
    if ($create_when_missing) {
      $self->_create_genes($schema, $result);
    }

    return ($result, \%identifiers_matching_more_than_once, \%genes_matched_more_than_once);
  } else {
    return ({ $self->_create_genes($schema, $result) });
  }
}

# $confirm_genes will be true if we have just uploaded some genes
sub _edit_genes_helper
{
  my ($self, $c, $confirm_genes) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $form = $self->form();

  my @all_elements = (
      {
        name => 'gene-select', label => 'gene-select',
        type => 'Checkbox', default_empty_value => 1
      },
      {
        name => 'submit', type => 'Submit', value => 'Remove selected',
        name => 'continue', type => 'Submit', value => 'Continue',
      },
    );


  $form->elements([@all_elements]);

  $form->process();

  if (defined $c->req->param('continue')) {
    _redirect_and_detach($c);
  }

  if (defined $c->req->param('submit')) {
    if ($c->req()->param('submit')) {
      my @gene_ids = @{$form->param_array('gene-select')};

      if (@gene_ids == 0) {
        $st->{message} = 'No genes selected for deletion';
      } else {
        my $delete_sub = sub {
          for my $gene_id (@gene_ids) {
            my $gene = $schema->find_with_type('Gene', $gene_id);
            $gene->delete();
          }
        };
        $schema->txn_do($delete_sub);

        $self->state()->store_statuses($c->stash()->{schema});

        if ($self->get_ordered_gene_rs($schema)->count() == 0) {
          $self->unset_metadata($schema, Canto::Curs::State::CURATION_IN_PROGRESS_TIMESTAMP_KEY());
          $c->flash()->{message} = 'All genes removed from the list';
          _redirect_and_detach($c, 'gene_upload');
        } else {
          my $plu = scalar(@gene_ids) > 1 ? 's' : '';
          $st->{message} = 'Removed ' . scalar(@gene_ids) . " gene$plu from list";
        }
      }
    }
  }

  if ($confirm_genes) {
    $st->{title} = 'Confirm gene list for ' . $st->{pub}->uniquename();
  } else {
    $st->{title} = 'Gene list for ' . $st->{pub}->uniquename();
  }
  $st->{show_title} = 0;
  $st->{template} = 'curs/gene_list_edit.mhtml';

  $st->{form} = $form;

  $st->{gene_list} =
    [Canto::Controller::Curs->get_ordered_gene_rs($schema, 'primary_identifier')->all()];
}

sub edit_genes : Chained('top') Args(0) Form
{
  my $self = shift;
  my ($c) = @_;

  $self->_edit_genes_helper(@_, 0);
}

sub confirm_genes : Chained('top') Args(0) Form
{
  my $self = shift;
  my ($c) = @_;

  $self->_edit_genes_helper(@_, 1);
}

sub gene_upload : Chained('top') Args(0) Form
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  my $return_path = $c->req()->param("return_path");

  if (defined $return_path) {
    $st->{title} = 'Add to gene list for ' . $st->{pub}->uniquename();
  } else {
    $st->{title} = 'Create gene list for ' . $st->{pub}->uniquename();
  }

  $st->{show_title} = 0;

  $st->{template} = 'curs/gene_upload.mhtml';

  my $form = $self->form();

  # to prevent AngularJS from doing preventDefault on the form
  $form->action('?');
  my @submit_buttons = ("Continue");

  my $schema = $st->{schema};

  my @no_genes_elements = ();
  my @no_genes_reasons =
    ( [ '', 'Please choose a reason ...' ],
      map { [ $_, $_ ] } @{$c->config()->{curs_config}->{no_genes_reasons}} );
  my @required_when = ();

  if ($st->{gene_count} > 0) {
    push @submit_buttons, "Back";
  } else {
    @no_genes_elements = (
      {
        name => 'no-genes', type => 'Checkbox',
        label => 'This paper does not contain any gene-specific information',
        default_empty_value => 1,
        attributes => { 'ng-model' => 'data.noAnnotation',
                        'ng-disabled' => 'data.geneIdentifiers.length > 0'  },
      },
      {
        name => 'no-genes-reason',
        type => 'Select', options => [ @no_genes_reasons ],
        attributes => { 'ng-model' => 'data.noAnnotationReason',
                        'ng-show' => 'data.noAnnotation' },
      },
      {
        name => 'no-genes-other', type => 'Text',
        attributes => { 'ng-show' => 'data.noAnnotation && data.noAnnotationReason === "Other"',
                        'ng-model' => 'data.otherText',
                        placeholder => 'Please specify' },
      },
    );
    @required_when = (when => { field => 'no-genes', not => 1, value => 1 });
  }

  my $not_valid_message = "Please enter some gene identifiers or choose a " .
    "reason for this paper having no annotatable genes";

  my @all_elements = (
      { name => $gene_list_textarea_name, type => 'Textarea', cols => 80, rows => 10,
        attributes => { 'ng-model' => 'data.geneIdentifiers',
                        'ng-disabled' => 'data.noAnnotation',
                        placeholder => "{{ data.noAnnotation ? 'No genes in this publication ' : '' }}" },
        constraints => [ { type => 'Length',  min => 1 },
                         { type => 'Required', @required_when },
                       ],
      },
      { name => 'return_path_input', type => 'Hidden',
        value => $return_path // '' },
      (map {
          {
            name => $_, type => 'Submit', value => $_,
            attributes => {
              class => 'button',
              title => "{{ isValid() ? '' : '$not_valid_message' }}",
              'ng-disabled' => '!isValid()',
            },
          }
        } @submit_buttons),
      @no_genes_elements,
    );

  $form->elements([@all_elements]);

  $form->process();

  $st->{form} = $form;

  if ($form->submitted()) {
    if (defined $c->req->param('Back')) {
      my $return_path = $form->param_value('return_path_input');

      if (defined $return_path && length $return_path > 0) {
        $c->res->redirect($return_path, 302);
        $c->detach();
        return 0;
      } else {
        _redirect_and_detach($c, 'edit_genes');
      }
    }
  }

  if ($form->submitted_and_valid()) {
    if ($form->param_value('no-genes')) {
      my $no_genes_reason =
        $form->param_value('no-genes-reason') // $form->param_value('no-genes-other');

      $no_genes_reason =~ s/^\s+//;
      $no_genes_reason =~ s/\s+$//;
      if (length $no_genes_reason > 0) {
        $self->set_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY(),
                            $no_genes_reason);
      } else {
        $st->{message} = $not_valid_message;
        return;
      }

      $c->flash()->{message} = "Annotation complete";

      _redirect_and_detach($c, 'finish_form');
    }

    my $search_terms_text = $form->param_value($gene_list_textarea_name);
    my @search_terms = grep { length $_ > 0 } split /[\s,]+/, $search_terms_text;

    $st->{search_terms_text} = $search_terms_text;

    my @res_list = $self->_find_and_create_genes($schema, $c->config(), \@search_terms);

    if (@res_list > 1) {
      # there was a problem
      my ($result, $identifiers_matching_more_than_once,
          $genes_matched_more_than_once) = @res_list;

      my @missing = @{$result->{missing}};
      my $error_title;
      my $error_text;
      if (@missing) {
        $error_title = "No genes found for these identifiers: @missing";
      } else {
        if (keys %$identifiers_matching_more_than_once > 0) {
          if (keys %$identifiers_matching_more_than_once > 1) {
            $error_title = 'Some of your identifiers match more than one gene: ';
          } else {
            $error_title = 'One of your identifiers matches more than one gene: ';
          }

          my @bits = ();
          while (my ($identifier, $gene_list) = each %$identifiers_matching_more_than_once) {
            my @gene_identifiers = map { qq("$_") } @$gene_list;
            my $last_identifier = pop @gene_identifiers;
            my $this_message = "$identifier matches ";
            $this_message .= join ', ', @gene_identifiers;
            $this_message .= " and $last_identifier";
            push @bits, $this_message;
          }

          $error_title .= join '; ', @bits;
        } else {
          if (keys %$genes_matched_more_than_once > 0) {
            $error_title = 'Some of your identifiers match the same gene: ';

            my @bits = ();
            while (my ($identifier, $gene_list) = each %$genes_matched_more_than_once) {
              my @gene_identifiers = map { qq("$_") } @$gene_list;
              my $last_identifier = pop @gene_identifiers;
              my $this_message = "found gene $identifier with ";
              $this_message .= join ', ', @gene_identifiers;
              $this_message .= " and $last_identifier";
              push @bits, $this_message;
            }

            $error_title .= join '; ', @bits;
          } else {
            die "internal error";
          }
        }

        $error_text = 'Enter only systematic identifiers to avoid this problem.';
      }

      $st->{error} = { title => $error_title };
      if (defined $error_text) {
        $st->{error}->{text} = $error_text;
      }
      $st->{gene_upload_unknown} = [@missing];
    } else {
      # no problems, so the result is the list of matching genes
      my ($result) = @res_list;

      my $matched_count = scalar(keys %$result);

      my $message = "Added $matched_count gene";
      $message .= 's' if ($matched_count > 1);

      $c->flash()->{message} = $message;

      if (!defined $self->get_metadata($schema, Canto::Curs::State::CURATION_IN_PROGRESS_TIMESTAMP_KEY())) {
        $self->set_metadata($schema, Canto::Curs::State::CURATION_IN_PROGRESS_TIMESTAMP_KEY(),
                            Canto::Util::get_current_datetime());
      }

      $self->state()->store_statuses($schema);

      my $return_path = $form->param_value('return_path_input');

      if (defined $return_path && length $return_path > 0) {
        $c->res->redirect($return_path, 302);
        $c->detach();
        return 0;
      } else {
        $c->flash()->{highlight_terms} = [@search_terms];
        _redirect_and_detach($c, 'confirm_genes');
      }
    }
  }
}

sub _delete_annotation : Private
{
  my ($self, $c, $annotation_id, $other_gene_identifier) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $schema->resultset('Annotation')->find($annotation_id);
  my $annotation_type_name = $annotation->type();
  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};
  if ($annotation_config->{category} eq 'interaction') {
    Canto::Curs::Utils::delete_interactor($annotation, $other_gene_identifier);
  } else {
    $annotation->delete();
  }
}

sub annotation_delete : Chained('top') PathPart('annotation/delete')
{
  my ($self, $c, $annotation_id, $other_gene_identifier) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->_check_annotation_exists($c, $annotation_id);

  my $delete_sub = sub {
    $self->_delete_annotation($c, $annotation_id, $other_gene_identifier);
    $self->metadata_storer()->store_counts($schema);
  };

  $schema->txn_do($delete_sub);

  _redirect_and_detach($c);
}

sub annotation_delete_suggestion : Chained('top') PathPart('annotation/delete_suggestion')
{
  my ($self, $c, $annotation_id) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->_check_annotation_exists($c, $annotation_id);

  my $delete_sub = sub {
    my $annotation = $schema->resultset('Annotation')->find($annotation_id);
    my $data = $annotation->data();
    delete $data->{term_suggestion};
    $annotation->data($data);
    $annotation->update();
    $self->metadata_storer()->store_counts($schema);
  };

  $schema->txn_do($delete_sub);

  _redirect_and_detach($c);
}

sub annotation_undelete : Chained('top') PathPart('annotation/undelete') Args(1)
{
  my ($self, $c, $annotation_id) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->_check_annotation_exists($c, $annotation_id);

  my $delete_sub = sub {
    my $annotation = $schema->resultset('Annotation')->find($annotation_id);
    $annotation->status('new');
    $annotation->update();
  };

  $schema->txn_do($delete_sub);

  $self->state()->store_statuses($schema);

  _redirect_and_detach($c);
}

sub _field_edit_internal
{
  my ($self, $c, $annotation_id, $field_name) = @_;

  my $annotation = $self->_check_annotation_exists($c, $annotation_id);
  my $data = $annotation->data();

  my $params = $c->req()->params();
  my $new_text = $params->{'curs-edit-dialog-text'};

  $data->{$field_name} = $new_text;

  $annotation->data($data);
  $annotation->update();

  $c->stash->{json_data} = {
    result => 'success',
  };
  $c->forward('View::JSON');
}

sub annotation_comment_edit : Chained('top') PathPart('annotation/comment_edit') Args(1)
{
  my ($self, $c, $annotation_id) = @_;

  _field_edit_internal(@_, 'submitter_comment');
}

sub annotation_extension_edit : Chained('top') PathPart('annotation/extension_edit') Args(1)
{
  _field_edit_internal(@_, 'annotation_extension');
}

my $iso_date_template = "%4d-%02d-%02d";

sub _get_iso_date
{
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
  return sprintf "$iso_date_template", 1900+$year, $mon+1, $mday
}

# change the annotation data of an existing annotation
sub _re_edit_annotation
{
  my $c = shift;
  my $annotation_config = shift;
  my $annotation_id = shift;
  my $new_annotation_data = shift // {};

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $schema->find_with_type('Annotation',
                                           {
                                             annotation_id => $annotation_id,
                                           });
  my $data = $annotation->data();

  my @alleles = $annotation->alleles();

  if ($annotation_config->{needs_allele} && !exists $data->{alleles_in_progress} &&
      @alleles > 0) {
    # undo the work of annotation_process_alleles()
    my %in_progress_data = ( id => 0 );
    if (@alleles > 1) {
      croak "can't handle multi-allele phenotypes";
    }

    my $allele = $alleles[0];

    $in_progress_data{allele_type} = $allele->type();

    if (defined $allele->name()) {
      $in_progress_data{name} = $allele->name();
    }
    if (defined $allele->description()) {
      $in_progress_data{description} = $allele->description();
    }

    $in_progress_data{evidence} = delete $data->{evidence_code};

    if (defined $data->{expression}) {
      $in_progress_data{expression} = $data->{expression};
    }
    delete $data->{expression};

    if (defined $data->{conditions}) {
      $in_progress_data{conditions} = $data->{conditions};
    } else {
      $in_progress_data{conditions} = [];
    }
    delete $data->{conditions};

    $schema->resultset('AlleleAnnotation')->search({ allele => $allele->allele_id(),
                                                     annotation => $annotation->annotation_id() })
      ->delete();

    if ($schema->resultset('AlleleAnnotation')
        ->search({ allele => $allele->allele_id() })->count() == 0) {
      # unreferenced so delete
      $allele->delete();
    }

    $schema->resultset('GeneAnnotation')->create({ gene => $allele->gene()->gene_id(),
                                                   annotation => $annotation->annotation_id() });

    $new_annotation_data->{alleles_in_progress}->{0} = \%in_progress_data;
  }

  my $merge = Hash::Merge->new('RIGHT_PRECEDENT');
  my $new_data = $merge->merge($data, $new_annotation_data);

  $annotation->data($new_data);
  $annotation->update();

  return $annotation;
}

sub annotation_quick_add : Chained('top') PathPart('annotation/quick_add') Args(2)
{
  my ($self, $c, $gene_id, $annotation_type_name) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $params = $c->req()->params();

  my $evidence_types = $config->{evidence_types};

  my $_fail = sub {
    my $message = shift;

    $c->flash()->{error} = $message;
    $c->stash->{json_data} = {
      error => $message,
    };
    $c->forward('View::JSON');
  };

  my $evidence_code = $params->{'ferret-quick-add-evidence'};
  if (!defined $evidence_code ||
      !exists $config->{evidence_types}->{$evidence_code}) {
    $_fail->("Adding annotation failed - invalid evidence code");
    return;
  }

  my $termid = $params->{'ferret-quick-add-term-id'};
  if (!defined $termid || !defined _term_name_from_id($config, $termid)) {
    $_fail->("Adding annotation failed - invalid term name");
    return;
  }

  my $gene = $schema->find_with_type('Gene', $gene_id);

  my %annotation_data = (
    term_ontid => $termid,
    evidence_code => $evidence_code,
  );

  my $extension = $params->{'ferret-quick-add-extension'};

  $extension = trim($extension);

  if (length $extension > 0) {
    $annotation_data{annotation_extension} = $extension;
  }

  my $needs_with_gene = $evidence_types->{$evidence_code}->{with_gene};
  if ($needs_with_gene) {
    my $with_gene = $params->{'ferret-quick-add-with-gene'};

    my $with_gene_object;

    if (defined $with_gene) {
      eval {
        $with_gene_object = $schema->find_with_type('Gene', { gene_id => $with_gene });
      };
    }

    if (defined $with_gene_object) {
      $annotation_data{with_gene} = $with_gene_object->primary_identifier();
    } else {
      $_fail->("Adding annotation failed - missing 'with' gene");
      return;
    }
  }

  my $new_annotation =
    $schema->create_with_type('Annotation',
                              {
                                type => $annotation_type_name,
                                status => 'new',
                                pub => $st->{pub},
                                creation_date => _get_iso_date(),
                                data => { %annotation_data }
                              });

  $self->_set_annotation_curator($c, $new_annotation);

  $new_annotation->set_genes($gene);

  $c->stash->{json_data} = {
    new_annotation_id => $new_annotation->annotation_id(),
  };
  $c->forward('View::JSON');
}

# Set the "curator" field of the data blob of an Annotation to be the current
# curator.
# The current curator will be the reviewer if approval is in progress.
sub _set_annotation_curator
{
  my $self = shift;
  my $c = shift;
  my $annotation = shift;

  my $st = $c->stash();
  my $curs_key = $st->{curs_key};

  my $curator_email;
  my $curator_name;
  my $curator_known_as;
  my $accepted_date;
  my $community_curated;

  if ($st->{state} eq APPROVAL_IN_PROGRESS) {
    my $schema = $st->{schema};
    $curator_name = $self->get_metadata($schema, 'approver_name');
    $curator_email = $self->get_metadata($schema, 'approver_email');
  } else {
    ($curator_email, $curator_name, $curator_known_as,
     $accepted_date, $community_curated) =
      $self->curator_manager()->current_curator($curs_key);
  }

  my $data = $annotation->data();
  $data->{curator} = {
    email => $curator_email,
    name => $curator_name,
    community_curated => $community_curated // 0,
  };

  $annotation->data($data);
  $annotation->update();
}

sub annotation_ontology_edit
{
  my ($self, $c, $gene_proxy, $annotation_config, $annotation_id) = @_;

  my $module_display_name = $annotation_config->{display_name};

  my $annotation_type_name = $annotation_config->{name};
  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $module_category = $annotation_config->{category};

  # don't set stash title - use default
  $st->{current_component} = $annotation_type_name;
  $st->{annotation_type_config} = $annotation_config;
  $st->{annotation_namespace} = $annotation_config->{namespace};
  $st->{current_component_display_name} = $module_display_name;
  $st->{current_component_short_display_name} =
    $annotation_config->{short_display_name};
  $st->{current_component_very_short_display_name} =
    $annotation_config->{very_short_display_name};
  $st->{current_component_suggest_term_help} =
    $annotation_config->{suggest_term_help_text};
  my $broad_term_suggestions = $annotation_config->{broad_term_suggestions};
  $broad_term_suggestions =~ s/\s+$//g;
  $st->{broad_term_suggestions} = $broad_term_suggestions;
  my $specific_term_examples = $annotation_config->{specific_term_examples};
  $specific_term_examples =~ s/\s+$//g;
  $st->{specific_term_examples} = $specific_term_examples;
  my $annotation_help_text = $annotation_config->{help_text};
  $st->{annotation_help_text} = $annotation_help_text;
  my $annotation_more_help_text = $annotation_config->{more_help_text};
  $st->{annotation_more_help_text} = $annotation_more_help_text;
  my $annotation_extra_help_text = $annotation_config->{extra_help_text};
  $st->{annotation_extra_help_text} = $annotation_extra_help_text;
  $st->{template} = "curs/modules/$module_category.mhtml";

  my $form = $self->form();

  my @all_elements = (
      {
        name => 'ferret-term-id', label => 'ferret-term-id',
        type => 'Hidden',
      },
      {
        name => 'ferret-suggest-name', label => 'ferret-suggest-name',
        type => 'Text',
      },
      {
        name =>'ferret-suggest-definition',
        label => 'ferret-suggest-definition',
        type => 'Text',
      },
      {
        name => 'ferret-submit', type => 'Submit',
      }
    );

  $form->elements([@all_elements]);
  $form->process();
  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $term_ontid = $form->param_value('ferret-term-id');
    my $submit_value = $form->param_value('ferret-submit');

    my $guard = $schema->txn_scope_guard;

    my %annotation_data = (term_ontid => $term_ontid);

    if ($submit_value eq 'Submit suggestion') {
      my $suggested_name = $form->param_value('ferret-suggest-name');
      my $suggested_definition =
        $form->param_value('ferret-suggest-definition');

      $suggested_name = trim($suggested_name);
      $suggested_definition = trim($suggested_definition);

      $annotation_data{term_suggestion} = {
        name => $suggested_name,
        definition => $suggested_definition
      };

      $c->flash()->{message} = 'Note that your term suggestion has been '
        . 'stored, but the gene will be temporarily '
        . 'annotated with the parent of your suggested new term';
    }

    my $is_new_annotation = 0;

    my $annotation;

    if (defined $annotation_id) {
      # change an existing annotation
      my $orig_annotation = $schema->find_with_type('Annotation',
                                                    {
                                                      annotation_id => $annotation_id,
                                                    });
      my %current_data = %{$orig_annotation->data()};
      @current_data{keys %annotation_data} = values %annotation_data;

      my $state = $st->{state};
      if ($state eq APPROVAL_IN_PROGRESS) {
        # during approval add the approver details to the annotation if they
        # make a change
        my $curator_name = $self->get_metadata($schema, 'approver_name');
        my $curator_email = $self->get_metadata($schema, 'approver_email');

        push @{$current_data{changed_by}}, {
          curator_name => $curator_name,
          curator_email => $curator_email,
          change_date => _get_iso_date(),
        }
      }

      $annotation = $orig_annotation;
      $annotation->data(\%current_data);
      $annotation->update();
   } else {
      $annotation =
        $schema->create_with_type('Annotation',
                                  {
                                    type => $annotation_type_name,
                                    status => 'new',
                                    pub => $st->{pub},
                                    creation_date => _get_iso_date(),
                                    data => { %annotation_data }
                                  });

      $annotation->set_genes($gene_proxy->cursdb_gene());

      $annotation_id = $annotation->annotation_id();

      $self->_set_annotation_curator($c, $annotation);

      $is_new_annotation = 1;
    }

    $guard->commit();

    $self->metadata_storer()->store_counts($schema);

    $_debug_annotation_ids = [$annotation_id];

    $self->state()->store_statuses($schema);

    if ($is_new_annotation) {
      if ($annotation_config->{needs_allele}) {
        _redirect_and_detach($c, 'annotation', 'allele_select', $annotation_id);
      } else {
        _redirect_and_detach($c, 'annotation', 'evidence', $annotation_id);
      }
    } else {
      _redirect_and_detach($c, 'gene', $gene_proxy->gene_id());
    }
  } else {
    if (defined $annotation_id) {
      my $annotation = $schema->find_with_type('Annotation',
                                               {
                                                 annotation_id => $annotation_id
                                               });
      my $data = $annotation->data();
      my @genes = $annotation->genes();

      if (@genes) {
        my $gene = $genes[0];
        my $gene_proxy = _get_gene_proxy($c->config(), $gene);
        $c->stash()->{message} = 'Editing annotation of ' .
          $gene_proxy->display_name() . ' with ' . $data->{term_ontid};
      } else {
        my $allele = ($annotation->alleles())[0];
        $c->stash()->{message} = 'Editing annotation of ' .
          $allele->display_name() . ' with ' . $data->{term_ontid};
      }
    }
  }
}

sub annotation_interaction_edit
{
  my ($self, $c, $gene_proxy, $annotation_config) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $module_display_name = $annotation_config->{display_name};
  my $annotation_type_name = $annotation_config->{name};

  my $module_category = $annotation_config->{category};

  # don't set stash title - use default
  $st->{current_component} = $annotation_type_name;
  $st->{current_component_display_name} = $annotation_config->{display_name};
  $st->{template} = "curs/modules/$module_category.mhtml";

  my $form = $self->form();

  $form->auto_fieldset(0);

  my $genes_rs = $self->get_ordered_gene_rs($schema, 'primary_identifier');

  my @options = ();

  while (defined (my $g = $genes_rs->next())) {
    my $g_proxy = _get_gene_proxy($config, $g);
    push @options, { value => $g_proxy->gene_id(),
                     label => $g_proxy->long_display_name() };
  }

  my @all_elements = (
      {
        name => 'prey', label => 'prey',
        type => 'Checkboxgroup',
        container_tag => 'div',
        label => '',
        options => [@options],
      },
      {
        name => 'interaction-submit', type => 'Submit',
        attributes => { class => 'curs-finish-button', },
        value => 'Proceed ->',
      }
    );

  $form->elements([@all_elements]);
  $form->process();
  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $submit_value = $form->param_value('interaction-submit');

    my @prey_params = @{$form->param_array('prey')};

    if (!@prey_params) {
      $st->{message} = 'You must select at least one gene that interacts with ' .
        $st->{gene}->display_name();
      return;
    }

    my $guard = $schema->txn_scope_guard;

    my @prey_identifiers =
      map {
        my $prey_gene = $schema->find_with_type('Gene', $_);
        {
          primary_identifier => $prey_gene->primary_identifier(),
        }
      } @prey_params;

    my %annotation_data = (interacting_genes => [@prey_identifiers]);

    my $annotation =
      $schema->create_with_type('Annotation',
                                {
                                  type => $annotation_type_name,
                                  status => 'new',
                                  pub => $st->{pub},
                                  creation_date => _get_iso_date(),
                                  data => { %annotation_data }
                                });

    $self->_set_annotation_curator($c, $annotation);

    $annotation->set_genes($gene_proxy->cursdb_gene());

    $guard->commit();

    my $annotation_id = $annotation->annotation_id();
    $_debug_annotation_ids = [$annotation_id];

    $self->state()->store_statuses($schema);

    _redirect_and_detach($c, 'annotation', 'evidence', $annotation_id);
  }
}

sub _get_gene_proxy
{
  my $config = shift;
  my $gene = shift;

  if (!defined $gene) {
    croak "no gene passed to _get_gene_proxy()";
  }

  return Canto::Curs::GeneProxy->new(config => $config,
                                      cursdb_gene => $gene);
}

sub _annotation_edit
{
  my ($self, $c, $gene_id, $annotation_type_name, $annotation_id) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $gene = $schema->find_with_type('Gene', $gene_id);

  my $gene_proxy = _get_gene_proxy($config, $gene);
  $st->{gene} = $gene_proxy;

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  $st->{annotation_type_config} = $annotation_config;

  my $annotation_display_name = $annotation_config->{display_name};
  my $gene_display_name = $gene_proxy->display_name();

  $st->{title} = "Curating $annotation_display_name for $gene_display_name\n";
  $st->{show_title} = 0;

  my %type_dispatch = (
    ontology => \&annotation_ontology_edit,
    interaction => \&annotation_interaction_edit,
  );

  $self->state()->store_statuses($schema);

  &{$type_dispatch{$annotation_config->{category}}}($self, $c, $gene_proxy,
                                                    $annotation_config, $annotation_id);
}

sub new_annotation : Chained('top') PathPart('annotation/new') Args(2) Form
{
  my ($self, $c, $gene_id, $annotation_type_name) = @_;

  _annotation_edit($self, $c, $gene_id, $annotation_type_name);
}

sub existing_annotation_edit : Chained('top') PathPart('annotation/edit') Args(3) Form
{
  my ($self, $c, $gene_id, $annotation_type_name, $annotation_id) = @_;

  _annotation_edit($self, $c, $gene_id, $annotation_type_name, $annotation_id);
}

# redirect to the annotation transfer page only if we've just created an
# ontology annotation and we have more than one gene
sub _maybe_transfer_annotation
{
  my $c = shift;
  my $annotation_ids = shift;
  my $annotation_config = shift;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $gene_count = $schema->resultset('Gene')->count();

  my $gene = $st->{gene};

  my $current_user = $c->user();

  if ($annotation_config->{category} eq 'ontology') {
    _redirect_and_detach($c, 'annotation', 'transfer', (join ',', @$annotation_ids));
  } else {
    if (defined $gene) {
      _redirect_and_detach($c, 'gene', $gene->gene_id());
    }
  }
}

sub _check_annotation_exists
{
  my $self = shift;
  my $c = shift;
  my $annotation_id = shift;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation =
    $schema->resultset('Annotation')->find($annotation_id);

  if (defined $annotation) {
    $c->stash()->{annotation} = $annotation;

    return $annotation;
  } else {
    $c->flash()->{error} = qq|No annotation found with id "$annotation_id" |;
    _redirect_and_detach($c);
  }
}

sub _generate_evidence_options
{
  my $evidence_types = shift;
  my $annotation_type_config = shift;

  my @codes = map {
    my $code = $_;
    my $type_conf = $evidence_types->{$_};
    if (!defined $type_conf) {
      die "no configuration for $_\n";
    }
    my $description = $type_conf->{name};
    if (!defined $description) {
      die "missing description for $_\n";
    }
    if ($description !~ /^$code/) {
      $description .= " ($_)";
    }
    [ $_, $description]
  } @{$annotation_type_config->{evidence_codes}};

  return @codes;
}

sub annotation_evidence : Chained('top') PathPart('annotation/evidence') Args(1) Form
{
  my ($self, $c, $annotation_id) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->_check_annotation_exists($c, $annotation_id);

  my $annotation = $schema->find_with_type('Annotation', $annotation_id);
  my $annotation_type_name = $annotation->type();

  my $gene = $annotation->genes()->first();
  if (!defined $gene) {
    $gene = $annotation->alleles()->first()->gene();
  }

  if (!defined $gene) {
    die "could not find a gene for annotation: " . $annotation_id;
  };

  my $gene_proxy = _get_gene_proxy($config, $gene);
  $st->{gene} = $gene_proxy;
  my $gene_display_name = $gene_proxy->display_name();

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  my $module_category = $annotation_config->{category};

  my $annotation_data = $annotation->data();
  my $term_ontid = $annotation_data->{term_ontid};

  if (defined $term_ontid) {
    $st->{title} = "Evidence for annotating $gene_display_name with $term_ontid";
  } else {
    $st->{title} = "Evidence for annotating $gene_display_name";
  }

  $st->{show_title} = 0;

  $st->{gene_display_name} = $gene_display_name;

  $st->{current_component} = $annotation_type_name;
  $st->{current_component_display_name} = $annotation_config->{display_name};
  $st->{template} = "curs/modules/${module_category}_evidence.mhtml";
  $st->{annotation} = $annotation;

  my $annotation_type_config = $config->{annotation_types}->{$annotation_type_name};
  my $evidence_types = $config->{evidence_types};

  my @codes = _generate_evidence_options($evidence_types, $annotation_type_config);
  my $form = $self->form();

  my $form_back_string = '<- Back';
  my $form_proceed_string = 'Proceed ->';

  my @all_elements = (
      {
        name => 'evidence-select',
        type => 'Select', options => [ @codes ],
        default => $annotation_data->{evidence_code},
      },
      {
        type => 'Block',
        tag => 'div',
        attributes => { class => 'clearall', },
      },
      {
        name => 'evidence-submit-back', type => 'Submit', value => $form_back_string,
        attributes => { class => 'curs-back-button', },
      },
      {
        name => 'evidence-submit-proceed', type => 'Submit', value => $form_proceed_string,
        attributes => { class => 'curs-finish-button', },
      },
    );

  $form->elements([@all_elements]);

  $form->process();

  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $data = $annotation->data();
    my $evidence_select = $form->param_value('evidence-select');

    if ($evidence_select eq '') {
      $c->flash()->{error} = 'Please choose an evidence type to continue';
      _redirect_and_detach($c, 'annotation', 'evidence', $annotation_id);
    }

    my $evidence_submit_back = $c->req->params->{'evidence-submit-back'};
    my $evidence_submit_proceed = $c->req->params->{'evidence-submit-proceed'};
    if (!defined $evidence_submit_proceed && !defined $evidence_submit_back) {
      _redirect_and_detach($c, 'annotation', 'evidence', $annotation_id);
    }

    my $existing_evidence_code = $data->{evidence_code};

    my $gene_id = $gene->gene_id();

    if (defined $evidence_submit_back) {
      if (defined $existing_evidence_code) {
         _redirect_and_detach($c, 'gene', $gene_id);
     } else {
        $self->_delete_annotation($c, $annotation_id);
        _redirect_and_detach($c, 'annotation', 'new', $gene_id, $annotation_type_name);
      }
    }

    $data->{evidence_code} = $evidence_select;

    my $needs_with_gene = $evidence_types->{$evidence_select}->{with_gene};

    if (!$needs_with_gene) {
      delete $data->{with_gene};
    }

    $annotation->data($data);
    $annotation->update();

    my @annotation_ids = ($annotation->annotation_id());

    # Hack to cope with interactions: at this stage we potentially
    # have one Annotation object for multiple interactions (one bait,
    # multi prey) because the user can choose more than one prey.
    # After choosing the evidence, delete the original Annotation and
    # create one per prey.
    if ($module_category eq 'interaction') {
      my @interacting_genes = @{$data->{interacting_genes}};

      if (@interacting_genes > 1) {
        my $bait_gene = $annotation->genes()->first();
        delete $data->{interacting_genes};

        my @new_annotations =
          map {
            my $data_clone = clone $data;

            $data_clone->{interacting_genes} = [$_];

            my $new_annotation =
              $schema->create_with_type('Annotation',
                                        {
                                          type => $annotation->type(),
                                          status => $annotation->status(),
                                          pub => $annotation->pub(),
                                          creation_date => _get_iso_date(),
                                          data => $data_clone,
                                        });

            $new_annotation->set_genes($bait_gene);

            $new_annotation;
          } @interacting_genes;

        $annotation->delete();

        @annotation_ids = map{ $_->annotation_id(); } @new_annotations;

        $_debug_annotation_ids = [@annotation_ids];
      }
    }

    $self->state()->store_statuses($schema);

    if ($needs_with_gene) {
      my @parts = ('annotation', 'with_gene', $annotation_id);
      if (defined $existing_evidence_code) {
        push @parts, 'edit';
      }
      _redirect_and_detach($c, @parts);
    } else {
      if ($annotation_config->{needs_allele} || defined $existing_evidence_code) {
        _redirect_and_detach($c, 'gene', $gene_id);
      } else {
        _maybe_transfer_annotation($c, [@annotation_ids], $annotation_config);
      }
    }
  }
}

sub allele_remove_action : Chained('top') PathPart('annotation/remove_allele_action') Args(2)
{
  my ($self, $c, $annotation_id, $allele_id) = @_;

  my $annotation = $self->_check_annotation_exists($c, $annotation_id);

  my $data = $annotation->data();
  my $alleles_in_progress = $data->{alleles_in_progress} // { };

  delete $alleles_in_progress->{$allele_id};

  $data->{alleles_in_progress} = $alleles_in_progress;
  $annotation->data($data);
  $annotation->update();

  $c->stash->{json_data} = {
    allele_id => $allele_id,
    annotation_id => $annotation_id,
  };
  $c->forward('View::JSON');
}

# add a new blob of allele data to alleles_in_progress in the annotation
sub _allele_add_action_internal
{
  my $config = shift;
  my $schema = shift;
  my $annotation = shift;
  my $allele_data_ref = shift;

  my $data = $annotation->data();
  my $alleles_in_progress = $data->{alleles_in_progress} // { };
  my $max_id = -1;

  map {
    if ($_ > $max_id) {
      $max_id = $_;
    }
  } keys %$alleles_in_progress;

  my $new_allele_id = $max_id + 1;

  my $new_allele_data = {
    id => $new_allele_id,
    %$allele_data_ref,
  };

  my $lookup = Canto::Track::get_adaptor($config, 'ontology');

  my $return_allele_data = clone $new_allele_data;

  if (exists $new_allele_data->{conditions}) {
    # replace term names with the ID if we know it otherwise assume that the
    # user has made up a condition
    map { my $name = $_;
          my $res = $lookup->lookup_by_name(ontology_name => 'phenotype_condition',
                                            term_name => $name);
          if (defined $res) {
            $_ = $res->{id};
          }
        } @{$new_allele_data->{conditions}};
  }

  $alleles_in_progress->{$new_allele_id} = $new_allele_data;
  $data->{alleles_in_progress} = $alleles_in_progress;
  $annotation->data($data);
  $annotation->update();

  my $allele_display_name =
    Canto::Curs::Utils::make_allele_display_name($allele_data_ref->{name},
                                                  $allele_data_ref->{description});

  $return_allele_data->{display_name} = $allele_display_name;

  return $return_allele_data;
}

sub allele_add_action : Chained('top') PathPart('annotation/add_allele_action') Args(1)
{
  my ($self, $c, $annotation_id) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $self->_check_annotation_exists($c, $annotation_id);

  my $params = $c->req()->params();

  my $condition_list = $params->{'curs-allele-condition-names'};

  if (defined $condition_list) {
    if (ref $condition_list) {
      # it's already a list
    } else {
      $condition_list = [$condition_list];
    }
  } else {
    $condition_list = [];
  }

  my $allele_name = $params->{'curs-allele-name'};
  if (defined $allele_name && length $allele_name == 0) {
    $allele_name = undef;
  }

  if (defined $allele_name) {
    $allele_name = trim($allele_name);
  }

  my $description = $params->{'curs-allele-description-input'};

  my $allele_type = $params->{'curs-allele-type'};
  my $allele_type_config = $config->{allele_types}->{$allele_type};

  if (!defined $description || length $description == 0) {
    $description = $params->{'curs-allele-type'};
  }

  $description = trim($description);

  if (exists $allele_type_config->{pre_store_substitution}) {
    local $_ = $description;
    eval $allele_type_config->{pre_store_substitution};
    if ($@) {
      die "internal error: pre_store_substitution for $allele_type has error: $@";
    }
  }

  my %allele_data = (name => $allele_name,
                     description => $description,
                     allele_type => $allele_type,
                     evidence => $params->{'curs-allele-evidence-select'},
                     conditions => $condition_list);

  if (defined $params->{'curs-allele-expression'}) {
    $allele_data{expression} = $params->{'curs-allele-expression'};
  }

  my $new_allele_data =
    _allele_add_action_internal($config, $schema, $annotation,
                                \%allele_data);

  $c->stash->{json_data} = $new_allele_data;
  $c->forward('View::JSON');
}

sub _get_all_alleles
{
  my $config = shift;
  my $schema = shift;
  my $gene = shift;

  my %results = ();

  my $allele_rs =
    $schema->resultset('Allele')->search({
      gene => $gene->gene_id(),
    });

  while (defined (my $allele = $allele_rs->next())) {
    my $allele_display_name = $allele->display_name();
    $results{$allele_display_name} = {
      name => $allele->name(),
      description => $allele->description(),
      primary_identifier => $allele->primary_identifier(),
      allele_type => $allele->type(),
    };
  }

  my $ann_rs = $gene->direct_annotations();

  while (defined (my $annotation = $ann_rs->next())) {
    my $data = $annotation->data();

    if (exists $data->{alleles_in_progress}) {
      for my $allele_data (values %{$data->{alleles_in_progress}}) {
        my $allele_display_name =
          Canto::Curs::Utils::make_allele_display_name($allele_data->{name},
                                                        $allele_data->{description});
        if (!exists $results{$allele_display_name}) {
          $results{$allele_display_name} = {
            name => $allele_data->{name},
            description => $allele_data->{description},
            allele_type => $allele_data->{allele_type},
          };
        }
      }
    }
  }

  return %results;
}

sub _term_name_from_id : Private
{
  my $config = shift;
  my $term_id = shift;

  my $lookup = Canto::Track::get_adaptor($config, 'ontology');
  my $res = $lookup->lookup_by_id(id => $term_id);

  if (defined $res) {
    return $res->{name};
  } else {
    return undef;
  }
}

sub _get_name_of_condition
{
  my $ontology_lookup = shift;
  my $termid = shift;

  eval {
    my $result = $ontology_lookup->lookup_by_id(id => $termid);
    if (defined $result) {
      $termid = $result->{name};
    } else {
      # user has made up a condition and there is no ontology term for it yet
    }
  };
  if ($@) {
    # probably not in the form DB:ACCESSION - user made it up
  }

  return $termid
}


sub _get_all_conditions
{
  my $config = shift;
  my $schema = shift;

  my $ontology_lookup = Canto::Track::get_adaptor($config, 'ontology');
  my $an_rs = $schema->resultset('Annotation');

  my %conditions = ();

  while (defined (my $an = $an_rs->next())) {
    my $data = $an->data();

    if (exists $data->{conditions}) {
      for my $condition (@{$data->{conditions}}) {
        $conditions{_get_name_of_condition($ontology_lookup, $condition)} = 1
      }
    }

    if (exists $data->{alleles_in_progress}) {
      while (my ($id, $allele_data) = each %{$data->{alleles_in_progress}}) {
        if (defined $allele_data->{conditions}) {
          map {
            $conditions{_get_name_of_condition($ontology_lookup, $_)} = 1;
          } @{$allele_data->{conditions}};
        }
      }
    }
  }

  return \%conditions;
}

sub _allele_data_for_js : Private
{
  my $config = shift;
  my $annotation = shift;

  my $alleles_in_progress = $annotation->data()->{alleles_in_progress};

  if (defined $alleles_in_progress) {
    my $ontology_lookup =
      Canto::Track::get_adaptor($config, 'ontology');

    my $ret = clone $alleles_in_progress;
    while (my ($id, $data) = each %$ret) {
      if (defined $data->{conditions}) {
        map {
          my $termid = $_;
          $_ = _get_name_of_condition($ontology_lookup, $termid);
        } @{$data->{conditions}};
      }
    }
    return $ret;
  } else {
    return {};
  }
}

sub _annotation_allele_select_internal
{
  my ($self, $c, $annotation_id, $editing) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->_check_annotation_exists($c, $annotation_id);

  my $guard = $schema->txn_scope_guard;
  my $annotation = $schema->find_with_type('Annotation', $annotation_id);

  my $annotation_type_name = $annotation->type();
  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};
  if ($editing) {
    $annotation = _re_edit_annotation($c, $annotation_config, $annotation_id);
  }

  my $gene = $annotation->genes()->first();
  my $gene_proxy = _get_gene_proxy($config, $gene);
  $st->{gene} = $gene_proxy;
  my $gene_display_name = $gene_proxy->display_name();

  my $module_category = $annotation_config->{category};

  my $annotation_data = $annotation->data();
  my $term_ontid = $annotation_data->{term_ontid};

  my $term_name = _term_name_from_id($config, $term_ontid);

  $st->{title} = "Choose allele(s) for $gene_display_name with $term_ontid ($term_name)";
  $st->{show_title} = 0;

  $st->{gene_display_name} = $gene_display_name;
  $st->{gene_id} = $gene->gene_id();
  $st->{annotation} = $annotation;

  $st->{allele_type_config} = $config->{allele_types};

  my @allele_type_options = map {
    [ $_->{name}, $_->{name} ];
  } @{$config->{allele_type_list}};

  $st->{allele_type_options} = \@allele_type_options;

  my $evidence_types = $config->{evidence_types};
  my $annotation_type_config = $config->{annotation_types}->{$annotation_type_name};
  my @evidence_codes = _generate_evidence_options($evidence_types, $annotation_type_config);

  $st->{evidence_select_options} = \@evidence_codes;

  my %existing_alleles_by_name = _get_all_alleles($config, $schema, $gene);
  $st->{existing_alleles_by_name} =
    [
      map {
        {
          value => $existing_alleles_by_name{$_}->{name},
          description => $existing_alleles_by_name{$_}->{description},
          allele_type => $existing_alleles_by_name{$_}->{allele_type},
          display_name => $_,
        }
      } keys %existing_alleles_by_name
    ];

  $st->{alleles_in_progress} = _allele_data_for_js($config, $annotation);
  $st->{current_conditions} = _get_all_conditions($config, $schema);

  $guard->commit();

  $st->{editing} = $editing;
  $st->{template} = "curs/modules/${module_category}_allele_select.mhtml";
}

sub annotation_allele_select : Chained('top') PathPart('annotation/allele_select') Args(1)
{
  _annotation_allele_select_internal(@_, 0);
}

sub annotation_allele_select_edit : Chained('top') PathPart('annotation/allele_select') Args(2)
{
  my ($self, $c, $annotation_id, $editing) = @_;

  if ($editing eq 'edit') {
    _annotation_allele_select_internal(@_, 1);
  } else {
    $self->not_found($c);
  }
}

sub _annotation_process_alleles_internal
{
  my ($self, $c, $annotation_id, $editing) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $self->_check_annotation_exists($c, $annotation_id);

  my $annotation_type_name = $annotation->type();
  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  my $data = $annotation->data();
  my $alleles_in_progress = $data->{alleles_in_progress};

  if (!defined $alleles_in_progress) {
    die "internal error: no alleles defined";
  }

  my @new_annotation_ids = ();

  my $gene = $annotation->genes()->first();

  my $process = sub {
    # create an annotation for each allele
    while (my ($id, $allele) = each %$alleles_in_progress) {
      my $name = $allele->{name};
      my $description = $allele->{description};
      my $allele_type = $allele->{allele_type};
      my $expression = $allele->{expression};
      my $evidence = $allele->{evidence};
      my $conditions = $allele->{conditions};

      my $new_data = {
        expression => $expression,
        evidence_code => $evidence,
        conditions => $conditions,
        term_ontid => $data->{term_ontid},
        annotation_extension => $data->{annotation_extension},
        curator => $data->{curator},
      };

      if (defined $data->{term_suggestion}) {
        $new_data->{term_suggestion} = $data->{term_suggestion};
      }

      my $annotation_create_args = {
        status => $annotation->status(),
        pub => $annotation->pub(),
        type => $annotation->type(),
        creation_date => $annotation->creation_date(),
        data => $new_data,
      };

      my $new_annotation =
        $schema->create_with_type('Annotation',
                                  $annotation_create_args);

      push @new_annotation_ids, $new_annotation->annotation_id();

      my %create_args = (
        type => $allele_type,
        description => $description,
        name => $name,
        gene => $gene->gene_id(),
      );

      my $new_allele =
        $schema->create_with_type('Allele', \%create_args);

      $schema->create_with_type('AlleleAnnotation',
                                {
                                  allele => $new_allele->allele_id(),
                                  annotation => $new_annotation->annotation_id(),
                                });
    }

    # delete the original annotation now it's been split
    $annotation->delete();
  };

  $schema->txn_do($process);

  $self->metadata_storer()->store_counts($schema);

  if (!$editing) {
    _maybe_transfer_annotation($c, \@new_annotation_ids, $annotation_config);
  } else {
    _redirect_and_detach($c, 'gene', $gene->gene_id());
  }
}

sub annotation_process_alleles : Chained('top') PathPart('annotation/process_alleles') Args(1)
{
  _annotation_process_alleles_internal(@_, 0);
}

sub annotation_process_alleles_edit : Chained('top') PathPart('annotation/process_alleles') Args(2)
{
  my ($self, $c, $annotation_id, $editing) = @_;

  if (defined $editing && $editing eq 'edit') {
    _annotation_process_alleles_internal(@_, 1);
  } else {
    $self->not_found($c);
  }
}

sub annotation_transfer : Chained('top') PathPart('annotation/transfer') Args(1) Form
{
  my ($self, $c, $annotation_ids) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my @annotation_ids = split /,/, $annotation_ids;
  my %annotation_by_id = ();

  map {
    $self->_check_annotation_exists($c, $_);
  } @annotation_ids;

  my @annotations = map {
    my $annotation = $schema->find_with_type('Annotation', $_);
    $annotation_by_id{$annotation->annotation_id()} = $annotation;
    $annotation;
  } @annotation_ids;

  my $annotation_type_name = $annotations[0]->type();

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  $st->{annotation_type} = $annotation_config;
  $st->{annotations} = \@annotations;
  $st->{annotation_comment_help_text} = [
    split /\n/, ($annotation_config->{annotation_comment_help_text} // '')
  ];

  my $module_category = $annotation_config->{category};

  my $display_name = undef;

  my $gene;

  my @genes = $annotations[0]->genes();
  if (@genes) {
    $gene = $genes[0];
  } else {
    $gene = $annotations[0]->alleles()->first()->gene();
  }

  my $gene_proxy = _get_gene_proxy($config, $gene);

  my $genes_rs = $self->get_ordered_gene_rs($schema, 'primary_identifier');

  my @options = ();

  while (defined (my $other_gene = $genes_rs->next())) {
    next if $gene->gene_id() == $other_gene->gene_id();

    my $other_gene_proxy = _get_gene_proxy($config, $other_gene);

    push @options, { value => $other_gene_proxy->gene_id(),
                     label => $other_gene_proxy->long_display_name() };
  }

  $st->{title} = "Finalise annotation";
  $st->{show_title} = 0;
  $st->{template} = "curs/modules/${module_category}_transfer.mhtml";

  my $form = $self->form();

  $form->auto_fieldset(0);

  my $gene_count = $genes_rs->count();

  my $annotation_0_data = $annotations[0]->data();
  my $evidence_or_term;
  if ($annotation_config->{needs_allele}) {
    my $term_ontid = $annotation_0_data->{term_ontid};
    $evidence_or_term = "($term_ontid)";
  } else {
    $evidence_or_term = "and evidence";
  }
  my $transfer_select_genes_text;

  if ($gene_count > 1) {
    $transfer_select_genes_text =
      'You can annotate other genes from your list with the '
        . "same term $evidence_or_term by selecting genes below:";
  } else {
    $transfer_select_genes_text =
      "You can annotate other genes with the same term $evidence_or_term "
        . 'by adding more genes from the publication:';
  }

  my @all_elements = ();

  if (@annotations == 1) {
    # hack: show a textfield for the comment and extension if there is
    # one annotation
    my $annotation = $annotations[0];
    my $existing_comment = $annotation->data()->{submitter_comment};

    my %comment_def = (
      name => 'annotation-comment-0',
      label => 'Optional comment:',
      type => 'Textarea',
      container_tag => 'div',
      container_attributes => {
        style => 'display: block',
        class => 'curs-transfer-comment-container',
      },
      attributes => { class => 'annotation-comment',
                      style => 'display: block' },
      cols => 80,
      rows => 6,
    );

    if (defined $existing_comment) {
      $comment_def{'value'} = $existing_comment;
    }

    push @all_elements, {
      %comment_def,
    };

    my $current_user = $c->user();

    if (defined $current_user && $current_user->is_admin() ||
        $config->{always_show_extensions} && lc $config->{always_show_extensions} ne 'no') {
      my $existing_extension = $annotation->data()->{annotation_extension};

      my %extension_def = (
        name => 'annotation-extension-0',
        label => 'Annotation extension:',
        type => 'Textarea',
        container_tag => 'div',
        container_attributes => {
          style => 'display: block',
          class => 'curs-transfer-extension-container',
        },
        attributes => { class => 'annotation-extension',
                        style => 'display: block' },
        cols => 80,
        rows => 6,
      );

      if (defined $existing_extension) {
        $extension_def{'value'} = $existing_extension;
      }

      push @all_elements, {
        %extension_def,
      };
    }
  }

  if (@options) {
    push @all_elements, (
      {
        type => 'Block',
        tag => 'div',
        content => $transfer_select_genes_text,
      },
      {
        name => 'dest', label => 'dest',
        type => 'Checkboxgroup',
        container_tag => 'div',
        label => '',
        options => [@options],
      },
    );
  }

  push @all_elements, {
    name => 'transfer-submit', type => 'Submit', value => 'Finish',
  };

  $form->elements([@all_elements]);
  $form->process();
  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $submit_value = $form->param_value('transfer-submit');

    my $guard = $schema->txn_scope_guard;

    my @dest_params = @{$form->param_array('dest')};

    if (@annotations == 1) {
      # hack: use a textfield for the comment and extension only if there is one annotation
      my $annotation = $annotations[0];

      my $comment = $form->param_value('annotation-comment-0');
      my $extension = $form->param_value('annotation-extension-0');
      my $data = $annotation->data();

      if ($comment && $comment !~ /^\s*$/) {
        $data->{submitter_comment} = $comment;
      } else {
        delete $data->{submitter_comment};
      }

      if ($extension && $extension !~ /^\s*$/) {
        $data->{annotation_extension} = $extension;
      } else {
        delete $data->{annotation_extension};
      }

      $annotation->data($data);
      $annotation->update();
    }

    if (@dest_params > 0) {
      my $first_annotation = $annotations[0];
      my $first_ann_data = $first_annotation->data();

      my $new_data = clone $first_ann_data;
      delete $new_data->{with_gene};
      delete $new_data->{annotation_extension};
      delete $new_data->{conditions};
      delete $new_data->{expression};
      if ($annotation_config->{needs_allele}) {
        # only transfer the term to the new annotation
        delete $new_data->{evidence_code};
      }

      my @dest_gene_identifiers = ();

      for my $dest_param (@dest_params) {
        my $dest_gene = $schema->find_with_type('Gene', $dest_param);

        my $new_annotation =
          $schema->create_with_type('Annotation',
                                    {
                                      type => $annotation_type_name,
                                      status => 'new',
                                      pub => $annotations[0]->pub(),
                                      creation_date => _get_iso_date(),
                                      data => $new_data,
                                    });
        $new_annotation->set_genes($dest_gene);

        my $gene_proxy = Canto::Curs::GeneProxy->new(config => $config,
                                                      cursdb_gene => $dest_gene);

        push @dest_gene_identifiers, $gene_proxy->display_name();
      }

      $c->flash()->{message} = 'Transferred annotation to: ' . join ',', @dest_gene_identifiers;
    }

    $guard->commit();

    $self->state()->store_statuses($schema);

    _redirect_and_detach($c, 'gene', $gene->gene_id());
  }
}

sub _annotation_with_gene_internal
{
  my ($self, $c, $annotation_id, $editing) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->_check_annotation_exists($c, $annotation_id);

  my $annotation = $schema->find_with_type('Annotation', $annotation_id);
  my $annotation_type_name = $annotation->type();

  my $gene = $annotation->genes()->first();
  my $gene_proxy = _get_gene_proxy($config, $gene);
  my $gene_display_name = $gene_proxy->display_name();

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  my $annotation_data = $annotation->data();
  my $evidence_code = $annotation_data->{evidence_code};
  my $term_ontid = $annotation_data->{term_ontid};

  my $module_category = $annotation_config->{category};

  $st->{title} = "Annotating $gene_display_name";
  $st->{show_title} = 0;
  $st->{current_component} = $annotation_type_name;
  $st->{current_component_display_name} = $annotation_config->{display_name};
  $st->{template} = "curs/modules/${module_category}_with_gene.mhtml";
  $st->{gene_display_name} = $gene_display_name;

  $st->{term_ontid} = $term_ontid;
  $st->{evidence_code} = $evidence_code;

  my @genes = ();

  my $gene_rs = $self->get_ordered_gene_rs($schema, 'primary_identifier');

  while (defined (my $gene = $gene_rs->next())) {
    my $gene_proxy = _get_gene_proxy($config, $gene);
    push @genes, [$gene->primary_identifier(), $gene_proxy->display_name()];
  }

  unshift @genes, [ '', 'Choose a gene ...' ];

  my $form = $self->form();

  my @all_elements = (
      {
        name => 'with-gene-select',
        type => 'Select', options => [ @genes ],
        default => $annotation_data->{with_gene},
      },
      {
        name => 'with-gene-proceed', type => 'Submit', value => 'Proceed ->',
      },
    );

  $form->elements([@all_elements]);

  $form->process();

  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $with_gene_select = $form->param_value('with-gene-select');

    if ($with_gene_select eq '') {
      $c->flash()->{error} = 'Please choose a gene to continue';
      my @args = ($c, 'annotation', 'with_gene', $annotation_id);
      if ($editing) {
        push @args, 'edit';
      }
      _redirect_and_detach(@args);
    }

    $annotation_data->{with_gene} = $with_gene_select;

    $annotation->data($annotation_data);
    $annotation->update();

    if ($editing) {
      _redirect_and_detach($c, 'gene', $gene->gene_id())
    } else {
      _maybe_transfer_annotation($c, [$annotation->annotation_id()], $annotation_config);
    }
  }

  $self->state()->store_statuses($schema);

}

sub annotation_with_gene_edit : Chained('top') PathPart('annotation/with_gene') Args(2) Form
{
  my ($self, $c, $annotation_id, $edit) = @_;

  if ($edit eq 'edit') {
    _annotation_with_gene_internal(@_, 1);
  } else {
    $self->not_found($c);
  }
}

sub annotation_with_gene : Chained('top') PathPart('annotation/with_gene') Args(1) Form
{
  _annotation_with_gene_internal(@_, 0);
}

sub gene : Chained('top') Args(1)
{
  my ($self, $c, $gene_id) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};
  my $config = $c->config();

  my $gene = $schema->find_with_type('Gene', $gene_id);
  my $gene_proxy = _get_gene_proxy($config, $gene);

  _set_genes_in_session($c);

  $st->{gene} = $gene_proxy;

  my $total_annotation_count = $schema->resultset('Annotation')->count();

  if ($total_annotation_count == 0 && $st->{state} eq CURATION_IN_PROGRESS) {
    $st->{message} =
      [qq|If you do not know which annotation type to use to describe your | .
        qq|experiment, please contact the helpdesk using the "Contact curators" link|];
  }

  $st->{title} = 'Gene: ' . $gene_proxy->display_name();
  # use only in header, not in body:
  $st->{show_title} = 1;
  $st->{template} = 'curs/gene_page.mhtml';
}

sub annotation_export : Chained('top') PathPart('annotation/export') Args(1)
{
  my ($self, $c, $annotation_type_name) = @_;

  my $schema = $c->stash()->{schema};
  my $config = $c->config();

  my $results = $self->get_annotation_table_tsv($config, $schema, $annotation_type_name);

  $c->res->content_type('text/plain');
  $c->res->body($results);
}

sub annotation_zipexport : Chained('top') PathPart('annotation/zipexport') Args(0)
{
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};
  my $config = $c->config();

  my $zip_data = $self->get_curs_annotation_zip($config, $schema);

  if (defined $zip_data) {
    my $st = $c->stash();
    my $pub_uniquename = $st->{pub}->uniquename();

    my $zip_file_name =
      'curation_' . $st->{curs_key} . '_' . $pub_uniquename . '.zip';

    $c->res->headers->header("Content-Disposition" =>
                               "attachment; filename=$zip_file_name");
    $c->res->content_type('application/zip');
    $c->res->body($zip_data);
  } else {
    die "annotation_zipexport() called with no results to export";
  }
}

sub finish_session : Chained('top') Arg(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};
  my $form = $self->form();

  my @all_elements = (
      {
        name => 'submit', type => 'Submit', value => 'Submit to curators',
      },
      {
        name => 'reasonText', type => 'Hidden',
      },
      {
        name => 'otherReason', type => 'Text',
      }
    );

  $form->elements([@all_elements]);

  $form->process();

  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $no_annotation = $form->param_value('no-annotation');
    my $reason = $form->param_value('reasonText');
    my $other_reason = $form->param_value('otherReason');

    if ($no_annotation eq 'on' && !defined $reason) {
      $c->stash()->{message} =
        'No reason given for having no annotation';
      _redirect_and_detach($c);
    } else {
      if (lc $reason eq 'other' && defined $other_reason) {
        $reason = $other_reason;
      }

      $self->set_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY(), $reason);
      _redirect_and_detach($c, 'finish_form');
    }
  } else {
    _redirect_and_detach($c);
  }
}

sub finish_form : Chained('top') Args(0)
{
  my ($self, $c, $arg) = @_;

  my $schema = $c->stash()->{schema};
  my $config = $c->config();

  my $st = $c->stash();

  $st->{title} = 'Curation finished';
  $st->{show_title} = 1;
  $st->{template} = 'curs/finish_form.mhtml';

  $st->{finish_help} = $c->config()->{messages}->{finish_form};

  my $form = $self->form();
  my @submit_buttons = ("Finish", "Back");

  my $finish_textarea = 'finish_textarea';

  my @all_elements = (
      {
        name => $finish_textarea, type => 'Textarea', cols => 80, rows => 20,
        default => $self->get_metadata($schema, MESSAGE_FOR_CURATORS_KEY) // '',
      },
      map {
          {
            name => $_, type => 'Submit', value => $_,
              attributes => { class => 'button', },
            }
        } @submit_buttons,
    );

  $form->elements([@all_elements]);

  $form->process();

  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    if (defined $c->req->params->{Finish}) {
      my $text = $form->param_value($finish_textarea);
      $text = trim($text);

      if (length $text > 0) {
        $self->set_metadata($schema, MESSAGE_FOR_CURATORS_KEY, $text);
      } else {
        $self->unset_metadata($schema, MESSAGE_FOR_CURATORS_KEY);
      }

      _redirect_and_detach($c, 'finished_publication');
    } else {
      _redirect_and_detach($c, 'reactivate_session');
    }
  } else {
    my $force = {};
    my $no_annotation_reason =
      $self->get_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY());
    if (defined $no_annotation_reason) {
      # user ticked the "no genes" checkbox on the gene upload page
      $force = { force => SESSION_ACCEPTED };

      $st->{no_annotation_reason} = $no_annotation_reason;
    }

    $self->state()->set_state($schema, NEEDS_APPROVAL, $force);
  }
}

sub finished_publication : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Finished publication';
  $st->{show_title} = 0;
  $st->{template} = 'curs/finished_publication.mhtml';

  my $schema = $c->stash()->{schema};

  my $no_annotation_reason =
    $self->get_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY());

  if (defined $no_annotation_reason) {
    $st->{no_annotation_reason} = $no_annotation_reason;
  }
}

sub session_exported : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Curation session exported';
  $st->{show_title} = 0;
  $st->{template} = 'curs/session_exported.mhtml';
}

sub pause_curation : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->state()->set_state($schema, CURATION_PAUSED);

  _redirect_and_detach($c);
}

sub _assign_session :Private
{
  my ($self, $c, $reassign) = @_;

  my $st = $c->stash();

  if ($c->stash()->{state} eq EXPORTED) {
    die "This session has now been exported and cannot be assigned or " .
      "reassigned";
  }

  if ($reassign) {
    $st->{title} = 'Reassign session';
  } else {
    $st->{title} = 'Curator details';
  }

  $st->{show_title} = 0;
  $st->{reassign} = $reassign;

  $st->{template} = 'curs/assign_session.mhtml';

  my $config = $c->config();

  my $introduction_text_name = 'submitter_name';
  my $introduction_text_email = 'submitter_email';

  my $curator_manager = $self->curator_manager();

  my ($current_submitter_email, $current_submitter_name) =
    $curator_manager->current_curator($st->{curs_key});

  $st->{current_submitter_email} = $current_submitter_email;

  my $form = $self->form();
  $form->attributes({ autocomplete => 'on' });

  my @all_elements = ();

  # $current_submitter_* will be set if the session has been assigned and sent
  # out by the curators
  my $default_submitter_name = ($reassign ? undef : $current_submitter_name);
  my $default_submitter_email = ($reassign ? undef : $current_submitter_email);

  my $demo_user_name = $config->{curs_config}->{demo_user_name};
  my $demo_user_email_address = $config->{curs_config}->{demo_user_email_address};

  if ($reassign && !defined $current_submitter_email) {
    my $last_reassigner_name = $c->session()->{last_reassigner_name};
    my $last_reassigner_email_address = $c->session()->{last_reassigner_email_address};

    if ($config->{demo_mode}) {
      $last_reassigner_name //= $demo_user_name;
      $last_reassigner_email_address //= $demo_user_email_address;
    }

    push @all_elements, (
      {
        type => 'Block', tag => 'p',
        content => 'Please let us know your name and email address for our records:'
      },
      {
        name => 'reassigner_name', label => 'Your name', type => 'Text', size => 40,
        constraints => [ { type => 'Length',  min => 1 }, 'Required' ],
        default => $last_reassigner_name,
      },
      {
        name => 'reassigner_email', label => 'Your email address', type => 'Text', size => 40,
        constraints => [ { type => 'Length',  min => 1 }, 'Required', 'Email' ],
        default => $last_reassigner_email_address,
      },
      {
        type => 'Block', tag => 'p',
        content =>
          'Please enter name and email address of the person you wish to assign ' .
          'this paper to.  ' .
          'The new curator will receive an email with the link to the entry page to ' .
          'curate the paper.',
      }
    );
  } else {
    if ($config->{demo_mode}) {
      $default_submitter_name //= $demo_user_name;
      $default_submitter_email //= $demo_user_email_address;
    }
  }

  push @all_elements, (
      {
        name => 'submitter_name',
        label => ucfirst (($reassign ? 'new curator ' : '') . 'name'),
        type => 'Text', size => 40,
        constraints => [ { type => 'Length',  min => 1 }, 'Required' ],
        default => $default_submitter_name,
      },
      {
        name => 'submitter_email',
        label => ucfirst (($reassign ? 'new curator ' : '') . 'email'),
        type => 'Text', size => 40,
        constraints => [ { type => 'Length',  min => 1 }, 'Required', 'Email' ],
        default => $default_submitter_email,
     },
      {
        name => 'submit', type => 'Submit', value => 'Continue',
        attributes => { class => 'button', },
      },
    );

  $form->elements([@all_elements]);

  $form->process();

  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $reassigner_name_value = $form->param_value('reassigner_name');
    if (defined $reassigner_name_value) {
      $reassigner_name_value = trim($reassigner_name_value);
      if ($reassigner_name_value =~ /\@/) {
        $c->stash()->{message} =
          "Names can't contain the '\@' character: $reassigner_name_value - please " .
            "try again";
        return;
      }
    }

    my $reassigner_name = $reassigner_name_value // $current_submitter_name;
    my $reassigner_email =
      $form->param_value('reassigner_email') // $current_submitter_email;

    if (defined $reassigner_email) {
      $reassigner_email = trim($reassigner_email);
    }

    my $submitter_name = trim($form->param_value('submitter_name'));
    my $submitter_email = trim($form->param_value('submitter_email'));

    if ($submitter_name =~ /\@/) {
      $c->stash()->{message} =
        "Names can't contain the '\@' character: $submitter_name - please " .
        "try again";
      return;
    }

    my $schema = Canto::Curs::get_schema($c);
    my $curs_key = $st->{curs_key};

    my $add_submitter = sub {
      if (!defined $current_submitter_email && defined $reassigner_email) {
        # used to pre-populate the reassign form next time
        $c->session()->{last_reassigner_name} = $reassigner_name;
        $c->session()->{last_reassigner_email} = $reassigner_email;
        $curator_manager->set_curator($curs_key, $reassigner_email,
                                      $reassigner_name);
      }
      if (!defined $current_submitter_email ||
          $submitter_email ne $current_submitter_email ||
          $submitter_name ne $current_submitter_name) {
        $curator_manager->set_curator($curs_key, $submitter_email,
                                      $submitter_name);
      }
      if (!$reassign) {
        $curator_manager->accept_session($curs_key);
      }
    };

    $schema->txn_do($add_submitter);

    $self->state()->store_statuses($schema);

    my $st = $c->stash();
    my $pub_uniquename = $st->{pub}->uniquename();

    if ($reassign) {
      my $subject = "Session $curs_key reassigned to $submitter_name <$submitter_email>";

      $self->_send_email_from_template($c, 'session_reassigned',
                                       { reassigner_name => $reassigner_name,
                                         reassigner_email => $reassigner_email } );
      $self->_send_email_from_template($c, 'reassigner',
                                       { recipient_name => $reassigner_name,
                                         reassigner_name => $reassigner_name,
                                         recipient_email => $reassigner_email,
                                         reassigner_email => $reassigner_email } );

      $c->flash()->{message} = "Session has been reassigned to: $submitter_email";

      my $all_sessions = $c->session()->{all_sessions} //= {};
      delete $all_sessions->{$curs_key};

      _redirect_to_top_and_detach($c);
    } else {
      $self->_send_email_from_template($c, 'session_accepted');
      _redirect_and_detach($c);
    }
  }
}

sub reassign_session : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  $self->_assign_session($c, 1);
}

sub assign_session : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  $self->_assign_session($c, 0);
}

sub curation_paused : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Curation paused';
  $st->{show_title} = 0;
  $st->{template} = 'curs/curation_paused.mhtml';
}

sub restart_curation : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->state()->set_state($schema, CURATION_IN_PROGRESS);

  $c->flash()->{message} = 'Session has been restarted';

  _redirect_and_detach($c);
}

sub reactivate_session : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  if ($c->stash()->{state} eq EXPORTED) {
    die "can't reactivate an exported session";
  }

  my $schema = $c->stash()->{schema};

  my $state = $c->stash()->{state};

  cluck "invalid state: $state, when reactivating session"
    unless $state eq NEEDS_APPROVAL or $state eq APPROVED;

  $self->state()->set_state($schema, CURATION_IN_PROGRESS,
                   { force => $state });

  $self->unset_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY());

  $self->set_metadata($schema, Canto::Curs::State::REACTIVATED_TIMESTAMP_KEY,
                      Canto::Util::get_current_datetime());
  $self->state()->store_statuses($c->stash()->{schema});

  $c->flash()->{message} = 'Session has been reactivated';

  _redirect_and_detach($c);
}

sub _start_approval
{
  my ($self, $c, $force) = @_;

  my $schema = $c->stash()->{schema};

  my $current_user = $c->user();

  if (defined $current_user && $current_user->is_admin()) {
    $self->state()->set_state($schema, APPROVAL_IN_PROGRESS,
                     {
                       current_user => $current_user,
                       force => $force,
                     });
  } else {
    $c->flash()->{error} = 'Only admin users can approve sessions';
  }

  _redirect_and_detach($c);

}

sub _send_mail
{
  my $self = shift;
  my $c = shift;

  die "@_" unless @_ % 2 == 0;

  my %args = @_;
  my $body = $args{body};
  my $subject = $args{subject};
  my $dest_email = $args{to};
  my $from = $args{from};

  my $config = $c->config();
  my $mail_sender = Canto::MailSender->new(config => $config);

  if ($dest_email eq 'admin') {
    $mail_sender->send_to_admin(subject => $subject,
                                body => $body);
  } else {
    $mail_sender->send(to => $dest_email,
                       from => $from,
                       subject => $subject,
                       body => $body);
  }
}

sub _send_email_from_template
{
  my $self = shift;
  my $c = shift;
  my $type = shift;
  my $extra_template_args = shift;

  my $config = $c->config();

  my $email_util = Canto::EmailUtil->new(config => $config);

  my $st = $c->stash();
  my $curs_key = $st->{curs_key};
  my $pub = $st->{pub};

  my ($submitter_email, $submitter_name, $submitter_known_as) =
    $self->curator_manager()->current_curator($curs_key);

  my $help_index = $c->uri_for($config->{help_path});

  my %args = (
    session_link => $st->{curs_root_uri},
    curator_name => $submitter_name,
    curator_known_as => $submitter_known_as,
    curator_email => $submitter_email,
    publication_uniquename => $pub->uniquename(),
    publication_title => $pub->title(),
    help_index => $help_index,
    logged_in_user => $c->user(),
  );

  @args{keys %{$extra_template_args}} = values %{$extra_template_args};

  my $recipient_email = $args{recipient_email} // $submitter_email;

  my ($subject, $body, $from) = $email_util->make_email($type, %args);

  $self->_send_mail($c, subject => $subject, body => $body, to => $recipient_email,
                    from => $from);
}

sub begin_approval : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  if ($c->stash()->{state} eq EXPORTED) {
    die "can't start approval of an exported session";
  }

  _start_approval(@_);
}

sub restart_approval : Chained('top') Args(0)
{
  _start_approval(@_, APPROVED);
}

sub complete_approval : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};

  my @messages = ();

  my $obsolete_term_count = 0;

  my $lookup = Canto::Track::get_adaptor($c->config(), 'ontology');

  my $ann_rs = $schema->resultset('Annotation');

  ANNOTATION:
  while (defined (my $ann = $ann_rs->next())) {
    my $data = $ann->data();

    if (defined $data) {
      my $term_ontid = $data->{term_ontid};

      if (defined $term_ontid) {
        my $term_details = $lookup->lookup_by_id(id => $term_ontid);

        if (defined $term_details) {
          if ($term_details->{is_obsolete}) {
            push @messages, {
              title => qq|Session can't be approved as there an obsolete term: $term_ontid|,
            };
            last ANNOTATION;
          }
        } else {
          push @messages, {
            title => qq|Session can't be approved as a term ID is not in the database: $term_ontid|,
          };
          last ANNOTATION;
        }
      }
    }
  }

  my $term_sugg_count = $self->get_metadata($schema, Canto::Curs::State::TERM_SUGGESTION_COUNT_KEY);
  if (defined $term_sugg_count && $term_sugg_count > 0) {
    push @messages, {
      title => q|Session can't be approved as there are outstanding term requests|,
    };
  }

  my $unknown_cond_count = $self->get_metadata($schema, Canto::Curs::State::UNKNOWN_CONDITIONS_COUNT_KEY);
  if (defined $unknown_cond_count && $unknown_cond_count > 0) {
    push @messages, {
      title => q|Session can't be approved as there are conditions that aren't in the condition ontology|,
    };
  }

  if (@messages) {
    $c->flash()->{error} = [@messages];
  } else {
    my $current_user = $c->user();

    $self->state()->set_state($schema, APPROVED,
                              {
                                current_user => $current_user,
                              });
    $c->flash()->{message} = 'Session approved';
  }

  _redirect_and_detach($c);
}

sub cancel_approval : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};
  $self->state()->set_state($schema, NEEDS_APPROVAL,
                            { force => APPROVAL_IN_PROGRESS });
  $c->flash()->{message} = 'Session approval cancelled';

  _redirect_and_detach($c);
}

sub end : Private
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  $c->stash()->{error_template} = 'curs/error.mhtml';

  Canto::Controller::Root::end(@_);
}

1;
