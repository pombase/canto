package PomCur::Controller::Curs;

use base 'Catalyst::Controller::HTML::FormFu';

=head1 NAME

PomCur::Controller::Curs - curs (curation session) controller

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Controller::Curs

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

use PomCur::Curs::State qw/:all/;

with 'PomCur::Role::MetadataAccess';
with 'PomCur::Curs::Role::GeneResultSet';

use Archive::Zip qw(:CONSTANTS :ERROR_CODES);
use IO::String;
use Clone qw(clone);
use Hash::Merge;

use PomCur::Track;
use PomCur::Curs::Utils;
use PomCur::Curs::MetadataStorer;

use constant {
  MESSAGE_FOR_CURATORS_KEY => 'message_for_curators',
};

# actions to execute for each state, undef for special cases
my %state_dispatch = (
  SESSION_CREATED, 'submitter_update',
  SESSION_ACCEPTED, 'gene_upload',
  CURATION_IN_PROGRESS, undef,
  CURATION_PAUSED, 'curation_paused',
  NEEDS_APPROVAL, 'finished_publication',
  APPROVAL_IN_PROGRESS, undef,
  APPROVED, 'finished_publication',
  EXPORTED, 'finished_publication',
);

# used by the tests to find the most reecently created annotation
our $_debug_annotation_id = undef;

has state => (is => 'ro', init_arg => undef,
              isa => 'PomCur::Curs::State',
              lazy_build => 1);

has metadata_storer => (is => 'ro', init_arg => undef,
                        isa => 'PomCur::Curs::MetadataStorer',
                        lazy_build => 1);

sub _build_state
{
  my $self = shift;
  my $state = PomCur::Curs::State->new();

  return $state;
}

sub _build_metadata_storer
{
  my $self = shift;
  my $storer = PomCur::Curs::MetadataStorer->new();

  return $storer;
}

=head2 top

 Action to set up stash contents for curs

=cut
sub top : Chained('/') PathPart('curs') CaptureArgs(1)
{
  my ($self, $c, $curs_key) = @_;

  my $st = $c->stash();

  $st->{curs_key} = $curs_key;
  my $schema = PomCur::Curs::get_schema($c);

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

  $st->{page_description_id} = 'curs-page-description';

  my $config = $c->config();

  $st->{annotation_types} = $config->{annotation_types};
  $st->{annotation_type_list} = $config->{annotation_type_list};

  my ($state, $submitter_email, $gene_count) = $self->state()->get_state($schema);
  $st->{state} = $state;

  if ($state eq APPROVAL_IN_PROGRESS) {
    my $approver_name = $self->get_metadata($schema, 'approver_name');
    my $approver_email = $self->get_metadata($schema, 'approver_email');
    $st->{notice} =
      "Session is being checked by $approver_name <$approver_email>";
  }

  $st->{first_contact_email} =
    $self->get_metadata($schema, 'first_contact_email');
  $st->{first_contact_name} =
    $self->get_metadata($schema, 'first_contact_name');
  $st->{is_admin_session} =
    $self->get_metadata($schema, 'admin_session');

  my $organism_rs = $schema->resultset('Organism')->search({}, { rows => 2});
  my $has_multiple_organisms = $organism_rs->count() > 1;

  $st->{multi_organism_mode} =
    $config->{multi_organism_mode} || $has_multiple_organisms;

  # curation_pub_id will be set if we are annotating a particular publication,
  # rather than annotating genes without a publication
  my $pub_id = $self->get_metadata($schema, 'curation_pub_id');
  $st->{pub} = $schema->find_with_type('Pub', $pub_id);

  die "internal error, can't find Pub for pub_id $pub_id"
    if not defined $st->{pub};

  if ($state ne SESSION_CREATED) {
    $st->{submitter_email} = $submitter_email;
    $st->{submitter_name} = $self->get_metadata($schema, 'submitter_name');
  }

  $st->{message_to_curators} =
    $self->get_metadata($schema, MESSAGE_FOR_CURATORS_KEY);

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
      $path =~ m:/(gene_upload|edit_genes|confirm_genes):) {
    $use_dispatch = 0;
  }
  if (($state eq NEEDS_APPROVAL || $state eq APPROVED) &&
      $path =~ m:/(ro|finish_form|reactivate_session|begin_approval|restart_approval):) {
    $use_dispatch = 0;
  }

  if ($state eq CURATION_PAUSED && $path =~ m:/restart_curation:) {
    $use_dispatch = 0;
  }

  if ($use_dispatch) {
    my $dispatch_dest = $state_dispatch{$state};
    if (defined $dispatch_dest) {
      $c->detach($dispatch_dest);
    }
  }
}

sub not_found: Private
{
  my ($self, $c) = @_;
  $c->forward('PomCur::Controller::Root', 'default');
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

sub front : Chained('top') PathPart('') Args(0)
{
  my ($self, $c) = @_;

  my $pub_uniquename = $c->stash()->{pub}->uniquename();
  $c->stash->{title} = "$pub_uniquename summary";
  # use only in header, not in body:
  $c->stash->{show_title} = 1;
  $c->stash->{template} = 'curs/front.mhtml';
}

=head2 read_only_summary

 This action show the summary in readonly mode.

=cut
sub read_only_summary : Chained('top') PathPart('ro') Args(0)
{
  my ($self, $c) = @_;

  $c->stash->{title} = 'Read only session summary';
  # use only in header, not in body:
  $c->stash->{show_title} = 0;
  $c->stash->{read_only_curs} = 1;
  $c->stash->{template} = 'curs/front.mhtml';

  my $pub_uniquename = $c->stash()->{pub}->uniquename();

  $c->stash()->{message} = "Reviewing annotation session for $pub_uniquename";
}

sub submitter_update : Private
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Curator details';
  $st->{show_title} = 0;
  $st->{template} = 'curs/submitter_update.mhtml';

  my $first_contact_name = $st->{first_contact_name};
  my $first_contact_email = $st->{first_contact_email};

  my $submitter_update_text_name = 'submitter_name';
  my $submitter_update_text_email = 'submitter_email';

  my $form = $self->form();

  my @all_elements = (
      {
        name => 'submitter_name', label => 'Name', type => 'Text', size => 40,
        value => $first_contact_name,
        constraints => [ { type => 'Length',  min => 1 }, 'Required' ],
      },
      {
        name => 'submitter_email', label => 'Email', type => 'Text', size => 40,
        value => $first_contact_email,
        constraints => [ { type => 'Length',  min => 1 }, 'Required', 'Email' ],
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
    my $submitter_name = $form->param_value('submitter_name');
    my $submitter_email = $form->param_value('submitter_email');

    my $schema = PomCur::Curs::get_schema($c);


    my $add_submitter = sub {
      $schema->create_with_type('Metadata', { key => 'submitter_email',
                                              value => $submitter_email });

      $schema->create_with_type('Metadata', { key => 'submitter_name',
                                              value => $submitter_name });
    };

    $schema->txn_do($add_submitter);

    $self->state()->store_statuses($c->config(), $schema);

    _redirect_and_detach($c);
  }
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
            PomCur::CursDB::Organism::get_organism($schema, $org_full_name,
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
  my $adaptor = PomCur::Track::get_adaptor($config, 'gene');

  my $result = $adaptor->lookup([@search_terms]);

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
    $self->_create_genes($schema, $result);

    return ();
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

        if ($self->get_ordered_gene_rs($schema)->count() == 0) {
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
    [PomCur::Controller::Curs->get_ordered_gene_rs($schema, 'primary_identifier')->all()];
}

sub edit_genes : Chained('top') Args(0) Form
{
  my $self = shift;
  my ($c) = @_;

  $self->_edit_genes_helper(@_, 0);
  $self->state()->store_statuses($c->config(), $c->stash()->{schema});
}

sub confirm_genes : Chained('top') Args(0) Form
{
  my $self = shift;
  my ($c) = @_;

  $self->_edit_genes_helper(@_, 1);
  $self->state()->store_statuses($c->config(), $c->stash()->{schema});
}

sub gene_upload : Chained('top') Args(0) Form
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Create gene list for ' . $st->{pub}->uniquename();
  $st->{show_title} = 0;

  $st->{template} = 'curs/gene_upload.mhtml';

  my $form = $self->form();
  my @submit_buttons = ("Continue");

  my $schema = $st->{schema};

  my @no_genes_element = ();
  my @required_when = ();

  if ($st->{gene_count} > 0) {
    push @submit_buttons, "Back";
  } else {
    @no_genes_element = {
      name => 'no-genes', type => 'Checkbox',
      label => 'Or: no for annotation in this paper',
      default_empty_value => 1
    };
    @required_when = (when => { field => 'no-genes', not => 1, value => 1 });
  }

  my @all_elements = (
      { name => $gene_list_textarea_name, type => 'Textarea', cols => 80, rows => 10,
        constraints => [ { type => 'Length',  min => 1 },
                         { type => 'Required', @required_when },
                       ],
      },
      { name => 'return_path_input', type => 'Hidden',
        value => $c->req()->param("return_path") // '' },
      @no_genes_element,
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
      $st->{message} = "Annotation complete";
      $c->detach('finish_form', ['no_genes']);
    }

    my $search_terms_text = $form->param_value($gene_list_textarea_name);
    my @search_terms = grep { length $_ > 0 } split /[\s,]+/, $search_terms_text;

    my ($result, $identifiers_matching_more_than_once, $genes_matched_more_than_once) =
      $self->_find_and_create_genes($schema, $c->config(), \@search_terms);

    if ($result) {
      # the search result is returned only if there was a problem
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
      $self->state()->store_statuses($c->config(), $schema);

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

sub annotation_delete : Chained('top') PathPart('annotation/delete')
{
  my ($self, $c, $annotation_id, $other_gene_identifier) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->_check_annotation_exists($c, $annotation_id);

  my $delete_sub = sub {
    my $annotation = $schema->resultset('Annotation')->find($annotation_id);
    my $annotation_type_name = $annotation->type();
    my $annotation_config = $config->{annotation_types}->{$annotation_type_name};
    if ($annotation_config->{category} eq 'interaction') {
      PomCur::Curs::Utils::delete_interactor($annotation, $other_gene_identifier);
    } else {
      $annotation->delete();
    }
    $self->metadata_storer()->store_counts($config, $schema);
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

  $self->state()->store_statuses($config, $schema);

  _redirect_and_detach($c);
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

      $suggested_name =~ s/^\s+//;
      $suggested_name =~ s/\s+$//;
      $suggested_definition =~ s/^\s+//;
      $suggested_definition =~ s/\s+$//;

      $annotation_data{term_suggestion} = {
        name => $suggested_name,
        definition => $suggested_definition
      };

      $self->metadata_storer()->store_counts($config, $schema);

      $c->flash()->{message} = 'Note that your term suggestion has been '
        . 'stored, but the gene will be temporarily '
        . 'annotated with the parent of your suggested new term';
    }

    my $is_new_annotation = 0;

    my $annotation;

    if (defined $annotation_id) {
      $annotation = _re_edit_annotation($c, $annotation_config, $annotation_id, \%annotation_data);
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

      $is_new_annotation = 1;
    }

    $guard->commit();

    $_debug_annotation_id = $annotation_id;

    $self->state()->store_statuses($c->config(), $schema);

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
        name => 'interaction-submit', type => 'Submit', value => 'Proceed ->',
      }
    );

  $form->elements([@all_elements]);
  $form->process();
  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $submit_value = $form->param_value('interaction-submit');

    my $guard = $schema->txn_scope_guard;

    my @prey_params = @{$form->param_array('prey')};
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

    $annotation->set_genes($gene_proxy->cursdb_gene());

    $guard->commit();

    my $annotation_id = $annotation->annotation_id();
    $_debug_annotation_id = $annotation_id;

    $self->state()->store_statuses($config, $schema);

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

  return PomCur::Curs::GeneProxy->new(config => $config,
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

  my $annotation_display_name = $annotation_config->{display_name};
  my $gene_display_name = $gene_proxy->display_name();

  $st->{title} = "Curating $annotation_display_name for $gene_display_name\n";
  $st->{show_title} = 0;

  my %type_dispatch = (
    ontology => \&annotation_ontology_edit,
    interaction => \&annotation_interaction_edit,
  );

  $self->state()->store_statuses($config, $schema);

  &{$type_dispatch{$annotation_config->{category}}}($self, $c, $gene_proxy,
                                                    $annotation_config, $annotation_id);
}

sub new_annotation_edit : Chained('top') PathPart('annotation/edit') Args(2) Form
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

  my $current_user = $c->user();

  if ($annotation_config->{category} eq 'ontology' &&
      ($gene_count > 1 || defined $current_user && $current_user->is_admin())) {
    _redirect_and_detach($c, 'annotation', 'transfer', (join ',', @$annotation_ids));
  } else {
    _redirect_and_detach($c);
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
    my $description = $evidence_types->{$_}->{name};
    if ($evidence_types->{$_}->{name} !~ /^$code/) {
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

  my @all_elements = (
      {
        name => 'evidence-select',
        type => 'Select', options => [ @codes ],
        default => $annotation_data->{evidence_code},
      },
      {
        name => 'evidence-proceed', type => 'Submit', value => 'Proceed ->',
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

    my $existing_evidence_code = $data->{evidence_code};

    $data->{evidence_code} = $evidence_select;

    my $needs_with_gene = $evidence_types->{$evidence_select}->{with_gene};

    if (!$needs_with_gene) {
      delete $data->{with_gene};
    }

    $annotation->data($data);
    $annotation->update();

    $self->state()->store_statuses($config, $schema);

    if ($needs_with_gene) {
      my @parts = ('annotation', 'with_gene', $annotation_id);
      if (defined $existing_evidence_code) {
        push @parts, 'edit';
      }
      _redirect_and_detach($c, @parts);
    } else {
      if ($annotation_config->{needs_allele} || defined $existing_evidence_code) {
        _redirect_and_detach($c, 'gene', $gene->gene_id());
      } else {
        _maybe_transfer_annotation($c, [$annotation->annotation_id()], $annotation_config);
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

  my $lookup = PomCur::Track::get_adaptor($config, 'ontology');

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
    PomCur::Curs::Utils::make_allele_display_name($allele_data_ref->{name},
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

  my $condition_list = $params->{'curs-allele-condition-names[tags][]'};

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

  my $description = $params->{'curs-allele-description-input'};

  my $allele_type = $params->{'curs-allele-type'};
  my $allele_type_config = $config->{allele_types}->{$allele_type};

  if (!defined $description || length $description == 0) {
    $description = $params->{'curs-allele-type'};
  }

  if (exists $allele_type_config->{pre_store_substitution}) {
    local $_ = $description;
    eval $allele_type_config->{pre_store_substitution};
    if ($@) {
      die "internal error: pre_store_substitution for $allele_type has error: $@";
    }
  }

  my %allele_data = (name => $allele_name,
                     description => $description,
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
    };
  }

  my $ann_rs = $gene->direct_annotations();

  while (defined (my $annotation = $ann_rs->next())) {
    my $data = $annotation->data();

    if (exists $data->{alleles_in_progress}) {
      for my $allele_data (values %{$data->{alleles_in_progress}}) {
        my $allele_display_name =
          PomCur::Curs::Utils::make_allele_display_name($allele_data->{name},
                                                        $allele_data->{description});
        if (!exists $results{$allele_display_name}) {
          $results{$allele_display_name} = {
            name => $allele_data->{name},
            description => $allele_data->{description},
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
  my $type_name = shift;
  my $term_id = shift;

  my $lookup = PomCur::Track::get_adaptor($config, 'ontology');

  my $res = $lookup->lookup(ontology_name => $type_name,
                            search_string => $term_id,
                            max_results => 1);

  return $res->[0]->{name};
}

sub _allele_data_for_js : Private
{
  my $config = shift;
  my $annotation = shift;

  my $alleles_in_progress = $annotation->data()->{alleles_in_progress};

  if (defined $alleles_in_progress) {
    my $ontology_lookup =
      PomCur::Track::get_adaptor($config, 'ontology');

    my $ret = clone $alleles_in_progress;
    while (my ($id, $data) = each %$ret) {
      if (defined $data->{conditions}) {
        map {
          my $term_id = $_;
          eval {
            my $result = $ontology_lookup->lookup_by_id(id => $term_id);
            if (defined $result) {
              $_ = $result->{name};
            } else {
              # user has made up a condition
            }
          };
          if ($@) {
            # probably not in the form DB:ACCESSION - user made it up
          }
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

  my $term_name = _term_name_from_id($config, $annotation_type_name, $term_ontid);

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
          display_name => $_,
        }
      } keys %existing_alleles_by_name
    ];

  $st->{alleles_in_progress} = _allele_data_for_js($config, $annotation);

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
      my $expression = $allele->{expression};
      my $evidence = $allele->{evidence};
      my $conditions = $allele->{conditions};

      my $new_data = {
        expression => $expression,
        evidence_code => $evidence,
        conditions => $conditions,
        term_ontid => $data->{term_ontid},
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
        type => 'new',
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

  $self->metadata_storer()->store_counts($config, $schema);

  if (!$editing && $c->user_exists() && $c->user()->role()->name() eq 'admin') {
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

  for (my $i = 0; $i < @annotations; $i++) {
    my $annotation = $annotations[$i];
    my $existing_comment = $annotation->data()->{submitter_comment};
    my $label;

    if (@annotations > 1) {
      $label = 'Optional comment for annotation ' . ($i + 1)  . ':';
    } else {
      $label = 'Optional comment:'
    }

    my %comment_def = (
      name => 'annotation-comment-' . $i,
      label => $label,
      type => 'Textarea',
      container_tag => 'div',
      container_attributes => {
        style => 'display: ' . (@annotations == 1 ? 'block' : 'none'),
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
  }

  if ($c->user_exists() && $c->user()->role()->name() eq 'admin') {
    for (my $i = 0; $i < @annotations; $i++) {
      my $annotation = $annotations[$i];

      my $existing_extension = $annotation->data()->{annotation_extension};

      my %extension_def = (
        name => 'annotation-extension-' . $i,
        label => 'Add optional annotation extension for annotation ' . ($i + 1) . ':',
        type => 'Textarea',
        container_tag => 'div',
        attributes => { class => 'annotation-extension',
                        style => 'display: block' },
        cols => 80,
        rows => 6,
      );

      if (defined $existing_extension) {
        $extension_def{'value'} = $existing_extension;
      }

      push @all_elements, (
        {
          %extension_def,
        }
      );
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

    for (my $i = 0; $i < @annotations; $i++) {
      my $annotation = $annotations[$i];

      my $extension = $form->param_value('annotation-extension-' . $i);
      my $comment = $form->param_value('annotation-comment-' . $i);

      my $data = $annotation->data();
      if ($extension && $extension !~ /^\s*$/) {
        $data->{annotation_extension} = $extension;
      } else {
        delete $data->{annotation_extension};
      }

      if ($comment && $comment !~ /^\s*$/) {
        $data->{submitter_comment} = $comment;
      } else {
        delete $data->{submitter_comment};
      }

      $annotation->data($data);
      $annotation->update();
    }

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

      my $gene_proxy = PomCur::Curs::GeneProxy->new(config => $config,
                                                    cursdb_gene => $dest_gene);

      push @dest_gene_identifiers, $gene_proxy->display_name();
    }

    if(@dest_params > 0) {
      $c->flash()->{message} = 'Transferred annotation to: ' . join ',', @dest_gene_identifiers;
    }

    $guard->commit();

    $self->state()->store_statuses($config, $schema);

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

  $self->state()->store_statuses($config, $schema);

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

  $st->{gene} = $gene_proxy;

  $st->{title} = 'Gene: ' . $gene_proxy->display_name();
  # use only in header, not in body:
  $st->{show_title} = 1;
  $st->{template} = 'curs/gene_page.mhtml';
}

sub _get_annotation_table_tsv
{
  my $config = shift;
  my $schema = shift;
  my $annotation_type_name = shift;

  my $annotation_type = $config->{annotation_types}->{$annotation_type_name};

  my ($completed_count, $annotations_ref, $columns_ref) =
    PomCur::Curs::Utils::get_annotation_table($config, $schema,
                                              $annotation_type_name);
  my @annotations = @$annotations_ref;
  my %common_values = %{$config->{export}->{gene_association_fields}};

  my @ontology_column_names =
    qw(db gene_identifier gene_name_or_identifier
       qualifiers term_ontid publication_uniquename
       evidence_code with_or_from_identifier
       annotation_type_abbreviation
       gene_product gene_synonyms_string db_object_type taxonid
       creation_date_short db);

  my @interaction_column_names =
    qw(gene_identifier interacting_gene_identifier
       gene_taxonid interacting_gene_taxonid evidence_code
       publication_uniquename score phenotypes comment);

  my @column_names;

  if ($annotation_type->{category} eq 'ontology') {
    @column_names = @ontology_column_names;
  } else {
    @column_names = @interaction_column_names;
  }

  my $db = $config->{export}->{gene_association_fields}->{db};

  my $results = '';

  for my $annotation (@annotations) {
    next unless $annotation->{completed};

    $results .= join "\t", map {
      my $val = $common_values{$_};
      if (!defined $val) {
        $val = $annotation->{$_};
      }
      if ($_ eq 'taxonid') {
        $val = "taxon:$val";
      }
      if ($_ eq 'with_or_from_identifier') {
        if (defined $val && length $val > 0) {
          $val = "$db:$val";
        } else {
          $val = '';
        }
      }

      if (!defined $val) {
        die "no value for field $_";
      }

      $val;
    } @column_names;
    $results .= "\n";
  }

  return $results;
}

sub annotation_export : Chained('top') PathPart('annotation/export') Args(1)
{
  my ($self, $c, $annotation_type_name) = @_;

  my $schema = $c->stash()->{schema};
  my $config = $c->config();

  my $results = _get_annotation_table_tsv($config, $schema, $annotation_type_name);

  $c->res->content_type('text/plain');
  $c->res->body($results);
}

=head2 get_all_annotation_tsv

 Usage   : my $results_hash = get_all_annotation_tsv($config, $schema);
 Function: Return a hashref containing all the current annotations in tab
           separated values format.  The hash has the form:
             { 'cellular_component' => "...",
               'phenotype' => "..." }
           where the values are the TSV strings.
 Args    : $config - the Config object
           $schema - the CursDB object
 Returns : a hashref of results

=cut
sub get_all_annotation_tsv
{
  my $config = shift;
  my $schema = shift;

  my %results = ();

  for my $annotation_type (@{$config->{annotation_type_list}}) {
    my $annotation_type_name = $annotation_type->{name};
    my $results =
      _get_annotation_table_tsv($config, $schema, $annotation_type_name);
    if (length $results > 0) {
      $results{$annotation_type_name} = $results;
    }
  }

  return \%results;
}

=head2 get_all_annotation_zip

 Usage   : my $zip_data = get_all_annotation_zip($config, $schema);
 Function: return a data string containing all the annotations, stored in
           Zip format
 Args    : $config - the Config object
           $schema - the CursDB object
 Returns : the Zip data, or undef if there are no annotations

=cut
sub get_all_annotation_zip
{
  my $config = shift;
  my $schema = shift;

  my $results = get_all_annotation_tsv($config, $schema);

  if (keys %$results > 0) {
    my $zip = Archive::Zip->new();
    for my $annotation_type_name (keys %$results) {
      my $annotation_tsv =
        _get_annotation_table_tsv($config, $schema, $annotation_type_name);
      my $file_name = "$annotation_type_name.tsv";
      my $member = $zip->addString($annotation_tsv, $file_name);
      $member->desiredCompressionMethod(COMPRESSION_DEFLATED);
    }

    my $io = IO::String->new();

    $zip->writeToFileHandle($io);

    return ${$io->string_ref()}
  } else {
    return undef;
  }
}

sub annotation_zipexport : Chained('top') PathPart('annotation/zipexport') Args(0)
{
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};
  my $config = $c->config();

  my $zip_data = get_all_annotation_zip($config, $schema);

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

sub finish_form : Chained('top') Args(0)
{
  my ($self, $c, $arg) = @_;

  my $schema = $c->stash()->{schema};
  my $config = $c->config();

  my $st = $c->stash();

  $st->{title} = 'Finish curation session';
  $st->{show_title} = 0;
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
      $text =~ s/^\s+//;
      $text =~ s/\s+$//;

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
    if (defined $arg && $arg eq 'no_genes') {
      # user ticked the "no genes" checkbox on the gene upload page
      $force = { force => SESSION_ACCEPTED };
    }

    $self->state()->set_state($config, $schema, NEEDS_APPROVAL, $force);
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
}

sub pause_curation : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->state()->set_state($c->config(), $schema, CURATION_PAUSED);

  _redirect_and_detach($c);
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

  $self->state()->set_state($c->config(), $schema, CURATION_IN_PROGRESS);

  $c->flash()->{message} = 'Session has been restarted';

  _redirect_and_detach($c);
}

sub reactivate_session : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};

  my $state = $c->stash()->{state};

  croak "invalid state: $state, when reactivating session"
    unless $state eq NEEDS_APPROVAL or $state eq APPROVED;

  $self->state()->set_state($c->config(), $schema, CURATION_IN_PROGRESS,
                   { force => $state });

  $c->flash()->{message} = 'Session has been reactivated';

  _redirect_and_detach($c);
}

sub _start_approval
{
  my ($self, $c, $force) = @_;

  my $schema = $c->stash()->{schema};

  my $current_user = $c->user();

  if (defined $current_user && $current_user->is_admin()) {
    $self->state()->set_state($c->config(), $schema, APPROVAL_IN_PROGRESS,
                     {
                       current_user => $current_user,
                       force => $force,
                     });
  } else {
    $c->flash()->{error} = 'Only admin users can approve sessions';
  }

  _redirect_and_detach($c);

}

sub begin_approval : Chained('top') Args(0)
{
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

  my $term_sugg_count = $self->get_metadata($schema, PomCur::Curs::State::TERM_SUGGESTION_COUNT_KEY);
  if (defined $term_sugg_count && $term_sugg_count > 0) {
    push @messages, {
      title => q|Session can't be approved as there are outstanding term requests|,
    };
  }

  my $unknown_cond_count = $self->get_metadata($schema, PomCur::Curs::State::UNKNOWN_CONDITIONS_COUNT_KEY);
  if (defined $unknown_cond_count && $unknown_cond_count > 0) {
    push @messages, {
      title => q|Session can't be approved as there are conditions that aren't in the condition ontology|,
    };
  }

  if (@messages) {
    $c->flash()->{error} = [@messages];
  } else {
    my $current_user = $c->user();

    $self->state()->set_state($c->config(), $schema, APPROVED,
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
  $self->state()->set_state($c->config(), $schema, NEEDS_APPROVAL,
                            { force => APPROVAL_IN_PROGRESS });
  $c->flash()->{message} = 'Session approval cancelled';

  _redirect_and_detach($c);
}

sub end : Private
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  $c->stash()->{error_template} = 'curs/error.mhtml';

  PomCur::Controller::Root::end(@_);
}

1;
