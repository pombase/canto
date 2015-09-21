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

use IO::String;
use Clone qw(clone);
use Hash::Merge;
use Carp qw(cluck);
use JSON;
use List::MoreUtils;
use Try::Tiny;

use Canto::Track;
use Canto::Curs::Utils;
use Canto::Curs::MetadataStorer;
use Canto::Curs::AlleleManager;
use Canto::Curs::GeneManager;
use Canto::Curs::GenotypeManager;
use Canto::MailSender;
use Canto::EmailUtil;
use Canto::Curs::State;
use Canto::Curs::ServiceUtils;
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

with 'Canto::Role::MetadataAccess';
with 'Canto::Role::GAFFormatter';
with 'Canto::Curs::Role::GeneResultSet';
with 'Canto::Curs::Role::CuratorSet';

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

  $st->{gene_count} = $schema->resultset('Gene')->count();
  $st->{genotype_count} = $schema->resultset('Genotype')->count();

  if ($path =~ m!/ro/?$!) {
    $st->{read_only_curs} = 1;
    if ($state eq EXPORTED) {
      $st->{message} =
        ["Review only - this session has been exported so no changes are possible"];
    } else {
      if ($state eq NEEDS_APPROVAL || $state eq APPROVAL_IN_PROGRESS) {
        $st->{message} =
          ["Review only - this session has been submitted for approval so no changes are possible"];
      } else {
        $st->{message} =
          ["Review only - this session can be viewed but not edited"];
      }
    }
  }

  my $use_dispatch = 1;

  my $current_user = $c->user();

  if ($config->{canto_offline} && !$st->{read_only_curs} &&
        (!defined $current_user || !$current_user->is_admin()) &&
        $path !~ m:/(ws/\w+/list):) {
    $c->detach('offline_message');
    $use_dispatch = 0;
  }

  if ($state eq APPROVAL_IN_PROGRESS) {
    if ($c->user_exists() && $c->user()->role()->name() eq 'admin') {
      # fall through, use dispatch table
      my $unused_genotype_count = _unused_genotype_count($c);

      if ($unused_genotype_count > 0) {
        if ($st->{message}) {
          if (!ref $st->{message}) {
            $st->{message} = [$st->{message}];
          }
        } else {
          $st->{message} = [];
        }

        if ($unused_genotype_count == 1) {
          push @{$st->{message}}, "Warning: there is an unused genotype in this session";
        } else {
          push @{$st->{message}}, "Warning: there are $unused_genotype_count unused genotypes in this session";
        }
      }
    } else {
      if ($path !~ m!/ro/?$|ws/\w+/list!) {
        $c->detach('finished_publication');
      }
    }
  }

  if ($state eq SESSION_ACCEPTED &&
      $path =~ m:/(gene_upload|edit_genes|genotype_manage|confirm_genes|finish_form):) {
    $use_dispatch = 0;
  }

  if (($state eq NEEDS_APPROVAL || $state eq APPROVED) &&
      $path =~ m:/(ro|finish_form|reactivate_session|begin_approval|restart_approval|annotation/zipexport|ws/\w+/list):) {
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

sub _unused_genotype_count
{
  my $c = shift;
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $genotype_rs = $schema->resultset('Genotype')
    ->search({}, { where => \"genotype_id NOT IN (SELECT genotype FROM genotype_annotation)" });

  return $genotype_rs->count();
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
  $st->{template} = 'curs/front.mhtml';

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

# $confirm_genes will be true if we have just uploaded some genes
sub _edit_genes_helper
{
  my ($self, $c, $confirm_genes) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $form = $self->form();
  $form->attributes({ action => '?' });

  my @all_elements = (
      {
        name => 'gene-select', label => 'gene-select',
        label_tag => 'formfu-label',
        type => 'Checkbox', default_empty_value => 1
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
        label_tag => 'formfu-label',
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
          my $ret = {
            name => $_, type => 'Submit', value => $_,
            attributes => {
              class => 'btn btn-primary curs-finish-button button',
              title => "{{ isValid() ? '' : '$not_valid_message' }}",
            },
          };
          if ($_ eq 'Continue') {
            $ret->{attributes}->{'ng-disabled'} = '!isValid()';
          }
          $ret;
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

    my $gene_manager =
      Canto::Curs::GeneManager->new(config => $c->config(),
                                    curs_schema => $schema);

    my @res_list = $gene_manager->find_and_create_genes(\@search_terms);

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

sub genotype_manage : Chained('top')
{
  my ($self, $c, $flag) = @_;

  my $st = $c->stash();

  if (defined $flag && $flag eq 'ro') {
    $st->{read_only_curs} = 1;
  }

  $st->{title} = 'Genotypes for: ' . $st->{pub}->uniquename();
  $st->{template} = 'curs/genotype_manage.mhtml';
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

  $c->flash()->{message} = "Annotation deleted";
}

sub annotation_delete : Chained('annotation') PathPart('delete')
{
  my ($self, $c, $other_gene_identifier) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $st->{annotation};

  my $delete_sub = sub {
    $self->_delete_annotation($c, $annotation->annotation_id(), $other_gene_identifier);
    $self->metadata_storer()->store_counts($schema);
  };

  $schema->txn_do($delete_sub);

  _redirect_and_detach($c);
}

sub annotation_delete_suggestion : Chained('annotation') PathPart('delete_suggestion')
{
  my ($self, $c) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $st->{annotation};

  my $delete_sub = sub {
    my $data = $annotation->data();
    delete $data->{term_suggestion};
    $annotation->data($data);
    $annotation->update();
    $self->metadata_storer()->store_counts($schema);
  };

  $schema->txn_do($delete_sub);

  _redirect_and_detach($c);
}

sub _field_edit_internal
{
  my ($self, $c, $field_name) = @_;

  my $st = $c->stash();
  my $annotation = $st->{annotation};
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

sub annotation_comment_edit : Chained('annotation') PathPart('comment_edit') Args(1)
{
  _field_edit_internal(@_, 'submitter_comment');
}

sub annotation_extension_edit : Chained('annotation') PathPart('extension_edit') Args(1)
{
  _field_edit_internal(@_, 'annotation_extension');
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

  my $merge = Hash::Merge->new('RIGHT_PRECEDENT');
  my $new_data = $merge->merge($data, $new_annotation_data);

  $annotation->data($new_data);
  $annotation->update();

  return $annotation;
}

sub _create_annotation
{
  my ($self, $c, $annotation_type_name, $feature_type,
      $features, $annotation_data) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  if ($annotation_config->{category} eq 'ontology' &&
      !$annotation_data->{term_ontid}) {
    die "internal error: no term ontology ID (term_ontid) passed to _create_annotation()";
  }

  my $guard = $schema->txn_scope_guard;

  my $annotation =
      $schema->create_with_type('Annotation',
                                {
                                  type => $annotation_type_name,
                                  status => 'new',
                                  pub => $st->{pub},
                                  creation_date => Canto::Curs::Utils::get_iso_date(),
                                  data => clone $annotation_data,
                                });

  if ($feature_type eq 'gene') {
    my @genes = map {
      $_->cursdb_gene();
    } @$features;

    $annotation->set_genes(@genes);
  } else {
    $annotation->set_genotypes(@$features);
  }

  $self->set_annotation_curator($annotation);
  $guard->commit();

  $self->metadata_storer()->store_counts($schema);

  $_debug_annotation_ids = [$annotation->annotation_id()];

  $self->state()->store_statuses($schema);

  return $annotation;
}

sub annotation_ontology_edit
{
  my ($self, $c, $feature, $annotation_config) = @_;

  my $module_display_name = $annotation_config->{display_name};

  my $annotation_type_name = $annotation_config->{name};
  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $feature_type = $st->{feature_type};

  my $feature_id;

  if ($feature_type eq 'gene') {
    $feature_id = $feature->gene_id();
  } else {
    $feature_id = $feature->genotype_id();
  }

  my $module_category = $annotation_config->{category};

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
}

sub _get_gene_proxy
{
  my $config = shift;
  my $gene = shift;

  if (!defined $gene) {
    confess "no gene passed to _get_gene_proxy()";
  }

  return Canto::Curs::GeneProxy->new(config => $config,
                                      cursdb_gene => $gene);
}


sub annotate : Chained('feature') CaptureArgs(1)
{
  my ($self, $c, $id) = @_;

  my $st = $c->stash();
  my $config = $c->config();

  my $feature_type = $st->{feature_type};

  my $feature = $st->{schema}->find_with_type($feature_type, $feature_type . "_id", $id);

  if ($feature_type eq 'gene') {
    $feature = _get_gene_proxy($config, $feature);
  }

  $st->{feature} = $feature;
  $st->{features} = [$feature];
}

sub start_annotation : Chained('annotate') PathPart('start') Args(1)
{
  my ($self, $c, $annotation_type_name) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $feature = $st->{feature};
  my @features = @{$st->{features}};

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};
  $st->{annotation_type_config} = $annotation_config;
  $st->{annotation_type_name} = $annotation_type_name;

  my $annotation_display_name = $annotation_config->{display_name};

  my $display_names = join ',', map {
    $_->display_name();
  } @features;

  $st->{title} = "Curating $annotation_display_name for $display_names\n";
  $st->{show_title} = 0;

  my %type_dispatch = (
    ontology => \&annotation_ontology_edit,
    interaction => \&annotation_interaction_edit,
  );

  $self->state()->store_statuses($schema);

  my $category = $annotation_config->{category};

  if (!defined $category) {
    die "no category configured for annotation type: $annotation_type_name\n";
  }

  my $edit_func = $type_dispatch{$category};

  if (!defined $edit_func) {
    die qq(unknown category "$category" for annotation type: $annotation_type_name\n);
  }

  &{$edit_func}($self, $c, $feature, $annotation_config);
}

sub annotation : Chained('top') CaptureArgs(1)
{
  my ($self, $c, $annotation_ids) = @_;

  my $st = $c->stash();

  my @annotations = $self->_check_annotation_exists($c, $annotation_ids);

  $st->{annotations} = \@annotations;

  $st->{annotation} = $annotations[0];
}

=head2 annotation_features

 Usage   : my ($feature_type, @features) =
             annotation_features($config, $annotation);
 Function: Return the features and type of features for an annotation
 Args    : $config - an Canto::Config object
           $annotation - an Annotation object
 Return  : $feature_type - "gene" or "genotype"
           @features - the features of an annotation

=cut

sub annotation_features
{
  my $config = shift;
  my $annotation = shift;

  my @genes = $annotation->genes();

  if (@genes) {
    return ('gene', map { _get_gene_proxy($config, $_); } @genes);
  } else {
    return ('genotype', $annotation->genotypes());
  }
}

sub _check_annotation_exists
{
  my $self = shift;
  my $c = shift;
  my $annotation_ids = shift;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my @annotation_ids = split /,/, $annotation_ids;

  my @annotations = ();

  for my $annotation_id (@annotation_ids) {
    my $annotation =
      $schema->resultset('Annotation')->find($annotation_id);

    if (defined $annotation) {
      $c->stash()->{annotation} = $annotation;

      push @annotations, $annotation;
    } else {
      $c->flash()->{error} = qq|No annotation found with id "$annotation_id" |;
      _redirect_and_detach($c);
      return ();
    }
  }

  return @annotations;
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

sub annotation_set_term : Chained('annotate') PathPart('set_term') Args(1)
{
  my ($self, $c, $annotation_type_name) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $body_data = _decode_json_content($c);

  my $term_ontid = $body_data->{term_ontid};
  my $evidence_code = $body_data->{evidence_code};

  my @conditions = ();

  if (defined $body_data->{conditions}) {
    my $lookup = Canto::Track::get_adaptor($config, 'ontology');

    my @condition_names = map {
      $_->{name};
    } @{$body_data->{conditions}};

    my @conditions_with_ids =
      Canto::Curs::ConditionUtil::get_conditions_from_names($lookup,
                                                            \@condition_names);
    @conditions =
      map { $_->{term_id} // $_->{name} } @conditions_with_ids;
  }

  my $annotation_config = $st->{annotation_type_config};
  my $feature_type = $st->{feature_type};
  my $feature = $st->{feature};

  my $module_category = $annotation_config->{category};

  $st->{annotation_config} = $annotation_config;
  $st->{annotation_category} = $module_category;

  my %annotation_data = (term_ontid => $term_ontid,
                         evidence_code => $evidence_code,
                         conditions => \@conditions,
                       );

  my $suggested_name = trim($body_data->{term_suggestion}->{name});
  my $suggested_definition = trim($body_data->{term_suggestion}->{definition});

  $annotation_data{term_suggestion} = {
    name => $suggested_name,
    definition => $suggested_definition
  };

  if ($body_data->{with_gene_id}) {
    my $with_gene = $schema->find_with_type('Gene', $body_data->{with_gene_id});

    $annotation_data{with_gene} = $with_gene->primary_identifier();
  }

  $st->{show_title} = 0;

  $st->{current_component} = $annotation_type_name;
  $st->{current_component_display_name} = $annotation_config->{display_name};

  my $annotation_type_config = $config->{annotation_types}->{$annotation_type_name};
  my $evidence_types = $config->{evidence_types};

  my $annotation =
    $self->_create_annotation($c, $annotation_type_name,
                                  $feature_type, [$feature], \%annotation_data);


  $c->stash->{json_data} = {
    status => "success",
    location => $st->{curs_root_uri} . "/annotation/" .
      $annotation->annotation_id() . "/transfer",
  };

  $c->forward('View::JSON');
}

sub annotation_add_interaction : Chained('annotate') PathPart('add_interaction') Args(1)
{
  my ($self, $c, $annotation_type_name) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $body_data = _decode_json_content($c);

  my $evidence_code = $body_data->{evidence_code};
  my @prey_gene_ids = @{$body_data->{prey_gene_ids}};

  my $annotation_config = $st->{annotation_type_config};
  my $feature_type = $st->{feature_type};
  my $feature = $st->{feature};

  my $module_category = $annotation_config->{category};

  my $annotation_type_config = $config->{annotation_types}->{$annotation_type_name};
  my $evidence_types = $config->{evidence_types};

  for my $prey_gene_id (@prey_gene_ids) {
    my $prey_gene = $schema->find_with_type('Gene', $prey_gene_id);

    my %annotation_data = (evidence_code => $evidence_code,
                           interacting_genes =>
                             [{ primary_identifier => $prey_gene->primary_identifier() }]);

    my $annotation =
      $self->_create_annotation($c, $annotation_type_name,
                                $feature_type, [$feature], \%annotation_data);
  }

  $c->stash->{json_data} = {
    status => "success",
    location => $st->{curs_root_uri} . "/feature/$feature_type/view/" .
      $feature->feature_id(),
  };

  $c->forward('View::JSON');
}

sub allele_remove_action : Chained('annotation') PathPart('remove_allele_action') Args(1)
{
  my ($self, $c, $allele_id) = @_;

  my $annotation = $c->stash()->{annotation};

  my $data = $annotation->data();
  my $alleles_in_progress = $data->{alleles_in_progress} // { };

  delete $alleles_in_progress->{$allele_id};

  $data->{alleles_in_progress} = $alleles_in_progress;
  $annotation->data($data);
  $annotation->update();

  $c->stash->{json_data} = {
    allele_id => $allele_id,
    annotation_id => $annotation->annotation_id(),
  };
  $c->forward('View::JSON');
}

sub _trim
{
  my $str = shift;

  return undef unless defined $str;

  $str =~ s/\s+$//;
  $str =~ s/^\s+//;

  return $str;
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

  return %results;
}

sub _set_allele_select_stash
{
  my ($c, $annotation_type_name) = @_;

  my $config = $c->config();
  my $st = $c->stash();

  $st->{allele_type_config} = $config->{allele_types};

  $st->{allele_type_names} = [
    map {
      $_->{name};
    } @{$config->{allele_type_list}}
  ];

  if (defined $annotation_type_name) {
    my $evidence_types = $config->{evidence_types};

    my $annotation_type_config = $config->{annotation_types}->{$annotation_type_name};
    my @evidence_codes = _generate_evidence_options($evidence_types, $annotation_type_config);

    $st->{evidence_select_options} = \@evidence_codes;
  }
}

sub annotation_transfer : Chained('annotation') PathPart('transfer') Form
{
  my ($self, $c) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my @annotations = @{$st->{annotations}};

  my %annotation_by_id = ();

  map {
    my $annotation = $_;
    $annotation_by_id{$annotation->annotation_id()} = $annotation;
  } @annotations;

  my $annotation_type_name = $annotations[0]->type();

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  $st->{annotation_type} = $annotation_config;
  $st->{annotations} = \@annotations;
  $st->{annotation_comment_help_text} = [
    split /\n/, ($annotation_config->{annotation_comment_help_text} // '')
  ];

  my $module_category = $annotation_config->{category};

  my $display_name = undef;

  my ($feature_type, $feature) = annotation_features($config, $annotations[0]);

  $st->{feature} = $feature;
  $st->{feature_type} = $feature_type;

  my $genes_rs = $self->get_ordered_gene_rs($schema, 'primary_identifier');

  my @options = ();

  if ($feature_type eq 'gene') {
    while (defined (my $other_gene = $genes_rs->next())) {
      next if $feature->gene_id() == $other_gene->gene_id();

      my $other_gene_proxy = _get_gene_proxy($config, $other_gene);

      push @options, { value => $other_gene_proxy->gene_id(),
                       label => $other_gene_proxy->long_display_name(),
                       container_attributes => {
                         class => 'checkbox-gene-list',
                       }
                     };
    }

    @options = sort { $a->{label} cmp $b->{label} } @options;
  }

  $st->{title} = "Finalise annotation";
  $st->{show_title} = 0;
  $st->{template} = "curs/modules/${module_category}_transfer.mhtml";

  my $form = $self->form();
  $form->attributes({ action => '?' });

  $form->auto_fieldset(0);

  my $gene_count = $genes_rs->count();

  my $annotation_0_data = $annotations[0]->data();
  my $transfer_select_genes_text;

  if ($gene_count > 1) {
    $transfer_select_genes_text =
      'You can annotate other genes from your list with the '
        . "same term and evidence by selecting genes below:";
  } else {
    $transfer_select_genes_text =
      "You can annotate other genes with the same term and evidence "
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
      label_tag => 'formfu-label',
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
        label => 'Optional annotation extension:',
        label_tag => 'formfu-label',
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
        name => 'dest',
        type => 'Checkboxgroup',
        container_tag => 'div',
        label => '',
        options => [@options],
      },
    );
  }

  push @all_elements, {
    name => 'transfer-submit', type => 'Submit',
    attributes => { class => 'btn btn-primary curs-finish-button', },
    value => 'Finish',
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

      my @dest_gene_identifiers = ();

      for my $dest_param (@dest_params) {
        my $dest_gene = $schema->find_with_type('Gene', $dest_param);

        my $new_annotation =
          $schema->create_with_type('Annotation',
                                    {
                                      type => $annotation_type_name,
                                      status => 'new',
                                      pub => $annotations[0]->pub(),
                                      creation_date => Canto::Curs::Utils::get_iso_date(),
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

    _redirect_and_detach($c, 'feature', $feature_type, 'view', $feature->feature_id());
  }
}

sub feature : Chained('top') CaptureArgs(1)
{
  my ($self, $c, $feature_type) = @_;

  my $st = $c->stash();

  $st->{feature_type} = $feature_type;
}

sub feature_view : Chained('feature') PathPart('view')
{
  my ($self, $c, $ids, $flag) = @_;

  my $st = $c->stash();
  $st->{show_title} = 1;
  my $feature_type = $st->{feature_type};
  my $schema = $st->{schema};
  my $config = $c->config();

  if (defined $flag && $flag eq 'ro') {
    $st->{read_only_curs} = 1;
  }

  my @ids = split /,/, $ids;

  if ($feature_type eq 'gene') {
    my @gene_proxies = map {
      my $gene = $schema->find_with_type('Gene', $_);
      _get_gene_proxy($config, $gene);
    } @ids;

    my $first_gene_proxy = $gene_proxies[0];

    _set_genes_in_session($c);

    $st->{gene} = $first_gene_proxy;
    $st->{genes} = [@gene_proxies];

    $st->{feature} = $st->{gene};
    $st->{features} = $st->{genes};
 } else {
    if ($feature_type eq 'genotype') {
      my $genotype;

      my $genotype_id = $ids[0];

      # a bit hacky: if the ID is an integer assume it's CursDB Genotype,
      # otherwise it's an identifier of a Genotype from Chado
      if ($genotype_id =~ /^\d+$/) {
        $genotype = $schema->find_with_type('Genotype', $genotype_id);
      } else {
        my $genotype_manager =
          Canto::Curs::GenotypeManager->new(config => $c->config(),
                                            curs_schema => $schema);


        # pull from Chado and store in CursDB, $genotype_id is an
        # identifier/uniquename
        $genotype =
          $genotype_manager->find_and_create_genotype($genotype_id);
      }

      $st->{genotype} = $genotype;
      $st->{annotation_count} = $genotype->annotations()->count();

      $st->{feature} = $genotype;
      $st->{features} = [$genotype];
    } else {
      die "no such feature type: $feature_type\n";
    }
  }

  my $display_name = $st->{feature}->display_name();

  $st->{title} = ucfirst $feature_type . ": $display_name";
  $st->{template} = "curs/${feature_type}_page.mhtml";
}

sub feature_add : Chained('feature') PathPart('add')
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{show_title} = 1;

  my $feature_type = $st->{feature_type};

  if ($feature_type eq 'genotype') {
    _set_allele_select_stash($c);
  }

  $st->{annotation_count} = 0;

  $st->{edit_or_duplicate} = 'edit';

  $st->{title} = "Add a $feature_type";
  $st->{template} = "curs/${feature_type}_edit.mhtml";
}

sub _feature_edit_helper
{
  my ($self, $c, $edit_or_duplicate, $genotype_id) = @_;

  my $st = $c->stash();
  $st->{show_title} = 1;
  my $feature_type = $st->{feature_type};

  $st->{edit_or_duplicate} = $edit_or_duplicate;

  my $schema = $st->{schema};

  if ($feature_type eq 'genotype') {
    my $genotype = $schema->find_with_type('Genotype', $genotype_id);

    if ($c->req()->method() eq 'POST') {
      # store the changes
      my $body_data = _decode_json_content($c);

      my @alleles_data = @{$body_data->{alleles}};
      my $genotype_name = $body_data->{genotype_name};
      my $genotype_background = $body_data->{genotype_background};

      try {
        my $guard = $schema->txn_scope_guard();

        my $allele_manager =
          Canto::Curs::AlleleManager->new(config => $c->config(),
                                          curs_schema => $schema);

        my @alleles = ();

        my $curs_key = $st->{curs_key};

        for my $allele_data (@alleles_data) {
          my $allele = $allele_manager->allele_from_json($allele_data, $curs_key,
                                                         \@alleles);

          push @alleles, $allele;
        }

        my $genotype_manager =
          Canto::Curs::GenotypeManager->new(config => $c->config(),
                                            curs_schema => $schema);

        $genotype_manager->store_genotype_changes($curs_key, $genotype,
                                                  $genotype_name, $genotype_background,
                                                  \@alleles);

        $guard->commit();

        $c->stash->{json_data} = {
          status => "success",
          location => $st->{curs_root_uri} . "/feature/genotype/view/" . $genotype->genotype_id(),
        };
      } catch {
        $c->stash->{json_data} = {
          status => "error",
          message => "Storing changes to genotype failed: internal error - " .
            "please report this to the Canto developers",
        };
        warn $_;
      };

      $c->forward('View::JSON');
    } else {
      $st->{genotype_id} = $genotype->id();

      _set_allele_select_stash($c);

      $st->{feature} = $genotype;
      $st->{features} = [$genotype];

      if ($edit_or_duplicate eq 'edit') {
        $st->{annotation_count} = $genotype->annotations()->count();
      }

      my $display_name = $st->{feature}->display_name();

      if ($edit_or_duplicate eq 'edit') {
        $st->{title} = "Editing genotype: $display_name";
      } else {
        $st->{title} = "Adding a genotype";
      }
      $st->{template} = "curs/${feature_type}_edit.mhtml";
    }
  } else {
    die "can't edit feature type: $feature_type\n";
  }
}

sub feature_duplicate : Chained('feature') PathPart('duplicate')
{
  my ($self, $c, $genotype_id) = @_;

  $self->_feature_edit_helper($c, 'duplicate', $genotype_id);
}

sub feature_edit : Chained('feature') PathPart('edit')
{
  my ($self, $c, $genotype_id) = @_;

  $self->_feature_edit_helper($c, 'edit', $genotype_id);
}

sub _decode_json_content
{
  my $c = shift;

  my $content_file = $c->req()->body();
  my $json_content;

  # FIXME
  # body() returns a file name, so read the contents into a string - there
  # must be a better way
  {
    local $/;
    open my $fh, '<', $content_file or die "can't open $content_file\n";
    $json_content = <$fh>;
  }

  return decode_json($json_content);
}

sub genotype_store : Chained('feature') PathPart('store')
{

  my ($self, $c) = @_;
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $config = $c->config();

  my $body_data = _decode_json_content($c);

  my @alleles_data = @{$body_data->{alleles}};
  my $genotype_name = $body_data->{genotype_name};
  my $genotype_background = $body_data->{genotype_background};

  my @alleles = ();

  if ($genotype_name && $schema->resultset('Genotype')->find( { name => $genotype_name } )) {
    $c->stash->{json_data} = {
      status => "error",
      message => qq(A genotype already exists with the name "$genotype_name" - ) .
        "please choose another",
    };
  } else {
    try {
      my $curs_key = $st->{curs_key};

      my $allele_manager =
        Canto::Curs::AlleleManager->new(config => $c->config(),
                                        curs_schema => $schema);

      for my $allele_data (@alleles_data) {
        my $allele = $allele_manager->allele_from_json($allele_data, $curs_key,
                                                               \@alleles);

        push @alleles, $allele;
      }

      my $genotype_manager =
        Canto::Curs::GenotypeManager->new(config => $c->config(),
                                          curs_schema => $schema);

      my $existing_genotype = $genotype_manager->find_with_alleles(\@alleles);

      if ($existing_genotype) {
        my $alleles_string = "allele";
        if (@alleles > 1) {
          $alleles_string = "alleles";
        }
        if (defined $existing_genotype->name()) {
          $c->flash()->{message} = "Using existing genotype with the same $alleles_string: " .
            $existing_genotype->name();
        } else {
          $c->flash()->{message} = "Using existing genotype with the same $alleles_string";
        }

        $c->stash->{json_data} = {
          status => "existing",
          genotype_display_name => $existing_genotype->display_name(),
          location => $st->{curs_root_uri} . "/feature/genotype/view/" . $existing_genotype->genotype_id(),
        };
      } else {
        my $guard = $schema->txn_scope_guard();

        my $genotype = $genotype_manager->make_genotype($curs_key,
                                                        $genotype_name, $genotype_background, \@alleles);

        $guard->commit();

        $c->flash()->{message} = 'Created new genotype';

        $c->stash->{json_data} = {
          status => "success",
          genotype_display_name => $genotype->display_name(),
          location => $st->{curs_root_uri} . "/feature/genotype/view/" . $genotype->genotype_id(),
        };
      }
    } catch {
      $c->stash->{json_data} = {
        status => "error",
        message => "Storing new genotype failed: internal error - " .
          "please report this to the Canto developers",
      };
      warn $_;
    };
  }

  $c->forward('View::JSON');
}


sub annotation_export : Chained('top') PathPart('annotation_export') Args(1)
{
  my ($self, $c, $annotation_type_name) = @_;

  my $schema = $c->stash()->{schema};
  my $config = $c->config();

  my $results = $self->get_annotation_table_tsv($config, $schema, $annotation_type_name);

  $c->res->content_type('text/plain');
  $c->res->body($results);
}

sub annotation_zipexport : Chained('top') PathPart('annotation_zipexport') Args(0)
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
  $form->attributes({ action => '?' });
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
              attributes => {
                class => 'btn btn-primary curs-' . lc $_ . '-button',
              },
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

sub offline_message : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Canto preview';
  $st->{show_title} = 0;
  $st->{template} = 'curs/offline_message.mhtml';
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
  $form->attributes({ autocomplete => 'on', action => '?' });

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
        label_tag => 'formfu-label',
        constraints => [ { type => 'Length',  min => 1 }, 'Required' ],
        default => $last_reassigner_name,
      },
      {
        name => 'reassigner_email', label => 'Your email address', type => 'Text', size => 40,
        label_tag => 'formfu-label',
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
        label_tag => 'formfu-label',
        type => 'Text', size => 40,
        constraints => [ { type => 'Length',  min => 1 }, 'Required' ],
        default => $default_submitter_name,
      },
      {
        name => 'submitter_email',
        label => ucfirst (($reassign ? 'new curator ' : '') . 'email'),
        label_tag => 'formfu-label',
        type => 'Text', size => 40,
        constraints => [ { type => 'Length',  min => 1 }, 'Required', 'Email' ],
        default => $default_submitter_email,
     },
      {
        name => 'submit', type => 'Submit', value => 'Continue',
        attributes => { class => 'btn btn-primary curs-finish-button', },
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
              title => "Session can't be approved as there an obsolete term: $term_ontid",
            };
            last ANNOTATION;
          }
        } else {
          push @messages, {
            title => "Session can't be approved as a term ID is not in the database: $term_ontid",
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


sub ws : Chained('top') CaptureArgs(1)
{
  my ($self, $c, $type) = @_;

  $c->stash()->{ws_type} = $type;
}

=head2 ws_list

 Function: Web service for returning the data from a Curs as lists
 Args    : None - the $type comes from the stash

=cut

sub ws_list : Chained('ws') PathPart('list')
{
  my ($self, $c, @args) = @_;

  my $type = $c->stash()->{ws_type};
  my $schema = $c->stash()->{schema};
  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  if ($json_data) {
    push @args, $json_data;
  }

  $c->stash->{json_data} = $service_utils->list_for_service($type, @args);

  $c->forward('View::JSON');
}

=head2 ws_details

 Function: Web service for returning information about a Curs object
 Args    : $ws_type - object type from the stash (from sub ws)
           $id   - the object id (eg. geneotype_id)

=cut

sub ws_details : Chained('ws') PathPart('details')
{
  my ($self, $c, @args) = @_;

  my $type = $c->stash()->{ws_type};
  my $schema = $c->stash()->{schema};
  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  if ($json_data) {
    push @args, $json_data;
  }

  $c->stash->{json_data} = $service_utils->details_for_service($type, @args);

  $c->forward('View::JSON');
}

sub ws_annotation : Chained('top') PathPart('ws/annotation') CaptureArgs(2)
{
  my ($self, $c, $annotation_id, $status) = @_;

  $c->stash()->{annotation_id} = $annotation_id;
  $c->stash()->{annotation_status} = $status;
}

sub ws_change_annotation : Chained('ws_annotation') PathPart('change')
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation_id = $st->{annotation_id};
  my $status = $st->{annotation_status};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  $c->stash->{json_data} =
    $service_utils->change_annotation($annotation_id, $status, $json_data);

  $c->forward('View::JSON');
}

sub ws_annotation_create : Chained('top') PathPart('ws/annotation/create')
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  $c->stash->{json_data} = $service_utils->create_annotation($json_data);

  $c->forward('View::JSON');
}

sub ws_annotation_delete : Chained('top') PathPart('ws/annotation/delete')
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  $c->stash->{json_data} = $service_utils->delete_annotation($json_data);

  $c->forward('View::JSON');
}

sub ws_genotype_delete : Chained('top') PathPart('ws/genotype/delete')
{
  my ($self, $c, $feature_id) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  my $guard = $schema->txn_scope_guard();

  $c->stash->{json_data} = $service_utils->delete_genotype($feature_id, $json_data);

  $guard->commit();

  $c->forward('View::JSON');
}

sub ws_add_gene : Chained('top') PathPart('ws/gene/add')
{
  my ($self, $c, $gene_identifier) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  $st->{json_data} = $service_utils->add_gene_by_identifier($gene_identifier);

  $c->forward('View::JSON');
}

sub ws_settings_get_all : Chained('top') PathPart('ws/settings/get_all')
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $data = {
    $self->all_metadata($schema),
  };

  $st->{json_data} = $data;

  $c->forward('View::JSON');
}

sub ws_settings_set : Chained('top') PathPart('ws/settings/set')
{
  my ($self, $c, $key, $value) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $allowed_keys = $c->config()->{curs_settings_service}->{allowed_keys};

  if ($allowed_keys->{$key}) {
    $self->set_metadata($schema, $key, $value);

    $st->{json_data} = {
      status => 'success',
    }
  } else {
    $st->{json_data} = {
      status => 'error',
      message => qq(setting with key "$key" not allowed),
    }
  }

  $c->forward('View::JSON');
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
