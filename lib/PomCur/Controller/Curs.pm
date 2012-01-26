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

with 'PomCur::Role::MetadataAccess';

use Archive::Zip qw(:CONSTANTS :ERROR_CODES);
use IO::String;
use Clone qw(clone);

use PomCur::Track;
use PomCur::Curs::Utils;

use constant {
  # user needs to confirm name and email address
  SESSION_CREATED => "SESSION_CREATED",
  # no genes in database, user needs to upload some
  SESSION_ACCEPTED => "SESSION_ACCEPTED",
  # session can be used for curation
  CURATION_IN_PROGRESS => "CURATION_IN_PROGRESS",
  # user has indicated that they are finished
  NEEDS_APPROVAL => "NEEDS_APPROVAL",
  # sessions is being checked by a curator
  APPROVAL_IN_PROGRESS => "APPROVAL_IN_PROGRESS",
  # session has been checked by a curator
  APPROVED => "APPROVED",
  # session has been exported to JSON
  EXPORTED => "EXPORTED",
};

use constant {
  NEEDS_APPROVAL_TIMESTAMP_KEY => 'needs_approval_timestamp',
  APPROVED_TIMESTAMP_KEY => 'approved_timestamp',
  APPROVAL_IN_PROGRESS_TIMESTAMP_KEY => 'approval_in_progress_timestamp',
  EXPORTED_TIMESTAMP_KEY => 'exported_timestamp',
  MESSAGE_FOR_CURATORS_KEY => 'message_for_curators',
  TERM_SUGGESTION_COUNT_KEY => 'term_suggestion_count'
};

# actions to execute for each state, undef for special cases
my %state_dispatch = (
  SESSION_CREATED, 'submitter_update',
  SESSION_ACCEPTED, 'gene_upload',
  CURATION_IN_PROGRESS, undef,
  APPROVAL_IN_PROGRESS, undef,
  NEEDS_APPROVAL, 'finished_publication',
  APPROVED, 'finished_publication',
  EXPORTED, 'finished_publication',
);

# used by the tests to find the most reecently created annotation
our $_debug_annotation_id = undef;

=head2 begin

 Action to set up stash contents for curs

=cut
sub top : Chained('/') PathPart('curs') CaptureArgs(1)
{
  my ($self, $c, $curs_key) = @_;

  my $st = $c->stash();

  $st->{curs_key} = $curs_key;
  my $schema = PomCur::Curs::get_schema($c);

  if (!defined $schema) {
    $c->res->redirect($c->uri_for('/404'));
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

  my ($state, $submitter_email, $gene_count) = _get_state($schema);
  $st->{state} = $state;

  if ($state eq APPROVAL_IN_PROGRESS) {
    $st->{notice} = 'Session is being checked';
  }

  $st->{first_contact_email} = get_metadata($schema, 'first_contact_email');
  $st->{first_contact_name} = get_metadata($schema, 'first_contact_name');
  $st->{is_admin_session} = get_metadata($schema, 'admin_session');

  my $organism_rs = $schema->resultset('Organism')->search({}, { rows => 2});
  my $has_multiple_organisms = $organism_rs->count() > 1;

  $st->{multi_organism_mode} =
    $config->{multi_organism_mode} || $has_multiple_organisms;

  # curation_pub_id will be set if we are annotating a particular publication,
  # rather than annotating genes without a publication
  my $pub_id = get_metadata($schema, 'curation_pub_id');
  $st->{pub} = $schema->find_with_type('Pub', $pub_id);

  if ($state ne SESSION_CREATED) {
    $st->{submitter_email} = $submitter_email;
    $st->{submitter_name} = get_metadata($schema, 'submitter_name');
  }

  $st->{gene_count} = get_ordered_gene_rs($schema)->count();

  if ($state eq APPROVAL_IN_PROGRESS &&
      !($c->user_exists() && $c->user()->role()->name() eq 'admin')) {
    $c->detach('finished_publication');
  } else {
    my $use_dispatch = 1;
    if ($state eq SESSION_ACCEPTED &&
        $path =~ /gene_upload|edit_genes|confirm_genes/) {
      $use_dispatch = 0;
    }
    if (($state eq NEEDS_APPROVAL || $state eq APPROVED) &&
        $path =~ /finish_form|reactivate_session|check_session/) {
      $use_dispatch = 0;
    }

    if ($use_dispatch) {
      my $dispatch_dest = $state_dispatch{$state};
      if (defined $dispatch_dest) {
        $c->detach($dispatch_dest);
      }
    }
  }
}

# Return a constant describing the state of the application, eg. SESSION_ACCEPTED
# or DONE.  See the %state hash above for details
sub _get_state
{
  my $schema = shift;

  my $submitter_email = get_metadata($schema, 'submitter_email');

  my $state = undef;
  my $gene_count = undef;

  if (defined $submitter_email) {
    my $gene_rs = get_ordered_gene_rs($schema);
    $gene_count = $gene_rs->count();

    if ($gene_count > 0) {
      if (defined get_metadata($schema, EXPORTED_TIMESTAMP_KEY)) {
        $state = EXPORTED;
      } else {
        if (defined get_metadata($schema, APPROVED_TIMESTAMP_KEY)) {
          $state = APPROVED;
        } else {
          if (defined get_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY)) {
            $state = APPROVAL_IN_PROGRESS;
          } else {
            if (defined get_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY)) {
              $state = NEEDS_APPROVAL;
            } else {
              $state = CURATION_IN_PROGRESS;
            }
          }
        }
      }
    } else {
      $state = SESSION_ACCEPTED;
    }
  } else {
    $state = SESSION_CREATED;
  }

  return ($state, $submitter_email, $gene_count);
}

=head2

 Usage   : PomCur::Controller::Curs::store_state($config, $schema)
 Function: Store all the current state via the status adaptor
 Args    : $config - the Config object
           $schema - the CursDB object
 Returns : nothing

=cut
sub store_statuses
{
  my $config = shift;
  my $schema = shift;

  my $adaptor = PomCur::Track::get_adaptor($config, 'status');

  my ($status, $submitter_email, $gene_count) = _get_state($schema);

  my $metadata_rs = $schema->resultset('Metadata');
  my $metadata_row = $metadata_rs->find({ key => 'curs_key' });

  if (!defined $metadata_row) {
    warn 'failed to read curs_key from: ', $schema->storage()->connect_info();
    return;
  }

  my $curs_key = $metadata_row->value();

  my $term_suggest_count_row =
    $metadata_rs->search({ key => TERM_SUGGESTION_COUNT_KEY })->first();

  my $term_suggestion_count;

  if (defined $term_suggest_count_row) {
    $term_suggestion_count = $term_suggest_count_row->value();
  } else {
    $term_suggestion_count = 0;
  }

  $adaptor->store($curs_key, 'annotation_status', $status);
  $adaptor->store($curs_key, 'session_genes_count', $gene_count // 0);
  $adaptor->store($curs_key, 'session_term_suggestions_count',
                  $term_suggestion_count);
}

sub _store_suggestion_count
{
  my $schema = shift;

  my $ann_rs = $schema->resultset('Annotation')->search();

  my $count = 0;

  while (defined (my $ann = $ann_rs->next())) {
    my $data = $ann->data();

    if (exists $data->{term_suggestion}) {
      $count++;
    }
  }

  set_metadata($schema, TERM_SUGGESTION_COUNT_KEY, $count);
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

  $c->stash->{title} = 'Front page';
  # use only in header, not in body:
  $c->stash->{show_title} = 0;
  $c->stash->{template} = 'curs/front.mhtml';
}

sub submitter_update : Private
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Curator details';
  $st->{show_title} = 0;
  $st->{template} = 'curs/submitter_update.mhtml';

  $st->{current_component} = 'submitter_update';

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

    store_statuses($c->config(), $schema);

    $schema->txn_do($add_submitter);

    _redirect_and_detach($c);
  }
}

my $gene_list_textarea_name = 'gene_identifiers';

# return a list of only those genes which aren't already in the database
sub _filter_existing_genes
{
  my $schema = shift;
  my @genes = @_;

  my @gene_primary_identifiers = map { $_->{primary_identifier} } @genes;

  my $gene_rs = get_ordered_gene_rs($schema);
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
  my $schema = shift;
  my $result = shift;

  my $_create_curs_genes = sub
      {
        my @genes = @{$result->{found}};

        @genes = _filter_existing_genes($schema, @genes);

        for my $gene (@genes) {
          my $org_full_name = $gene->{organism_full_name};
          my $org_taxonid = $gene->{organism_taxonid};
          my $curs_org =
            PomCur::CursDB::Organism::get_organism($schema, $org_full_name,
                                                   $org_taxonid);

          my $new_gene = $schema->create_with_type('Gene', {
            primary_name => $gene->{primary_name},
            primary_identifier => $gene->{primary_identifier},
            product => $gene->{product},
            organism => $curs_org
          });

          for my $synonym_identifier (@{$gene->{synonyms}}) {
            $schema->create_with_type('Genesynonym',
                                      {
                                        gene => $new_gene,
                                        identifier => $synonym_identifier,
                                      });
          }
        }
      };

  $schema->txn_do($_create_curs_genes);
}

sub _find_and_create_genes
{
  my ($schema, $config, $search_terms_ref, $create_when_missing) = @_;

  my @search_terms = @$search_terms_ref;
  my $adaptor = PomCur::Track::get_adaptor($config, 'gene');

  my $result = $adaptor->lookup([@search_terms]);

  if (@{$result->{missing}}) {
    if ($create_when_missing) {
      _create_genes($schema, $result);
    }

    return $result;
  } else {
    _create_genes($schema, $result);

    return undef;
  }
}

# $confirm_genes will be true if we have just uploaded some genes
sub _edit_genes_helper
{
  my ($self, $c, $confirm_genes) = @_;

  my $st = $c->stash();

  if ($confirm_genes) {
    $st->{title} = 'Confirm gene list for ' . $st->{pub}->uniquename();
  } else {
    $st->{title} = 'Gene list for ' . $st->{pub}->uniquename();
  }
  $st->{show_title} = 0;

  $st->{template} = 'curs/gene_list_edit.mhtml';

  $st->{current_component} = 'list_edit';

  my $config = $c->config();
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

  $st->{form} = $form;

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

        if (get_ordered_gene_rs($schema)->count() == 0) {
          $c->flash()->{message} = 'All genes removed from the list';
          _redirect_and_detach($c, 'gene_upload');
        } else {
          my $plu = scalar(@gene_ids) > 1 ? 's' : '';
          $st->{message} = 'Removed ' . scalar(@gene_ids) . " gene$plu from list";
        }
      }
    }
  }
}

sub edit_genes : Chained('top') Args(0) Form
{
  my $self = shift;
  my ($c) = @_;

  $self->_edit_genes_helper(@_, 0);
  store_statuses($c->config(), $c->stash()->{schema});
}

sub confirm_genes : Chained('top') Args(0) Form
{
  my $self = shift;
  my ($c) = @_;

  $self->_edit_genes_helper(@_, 1);
  store_statuses($c->config(), $c->stash()->{schema});
}

sub gene_upload : Chained('top') Args(0) Form
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Create gene list for ' . $st->{pub}->uniquename();
  $st->{show_title} = 0;

  $st->{template} = 'curs/gene_upload.mhtml';
  $st->{current_component} = 'gene_upload';

  my $form = $self->form();
  my @submit_buttons = ("Continue");

  my $schema = $st->{schema};

  if ($st->{gene_count} > 0) {
    push @submit_buttons, "Back";
  }

  my @all_elements = (
      { name => $gene_list_textarea_name, type => 'Textarea', cols => 80, rows => 10,
        constraints => [ { type => 'Length',  min => 1 }, 'Required' ],
      },
      { name => 'return_path_input', type => 'Hidden',
        value => $c->req()->param("return_path") // '' },
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
    my $search_terms_text = $form->param_value($gene_list_textarea_name);
    my @search_terms = grep { length $_ > 0 } split /[\s,]+/, $search_terms_text;

    my $result = _find_and_create_genes($schema, $c->config(), \@search_terms);

    store_statuses($c->config(), $schema);

    if ($result) {
      my @missing = @{$result->{missing}};
      $st->{error} =
          { title => "No genes found for these identifiers: @missing" };
      $st->{gene_upload_unknown} = [@missing];
    } else {
      my $return_path = $form->param_value('return_path_input');

      if (defined $return_path && length $return_path > 0) {
        $c->res->redirect($return_path, 302);
        $c->detach();
        return 0;
      } else {
        $c->flash()->{search_terms} = [@search_terms];
        _redirect_and_detach($c, 'confirm_genes');
      }
    }
  }
}

sub annotation_delete : Chained('top') PathPart('annotation/delete') Args(1)
{
  my ($self, $c, $annotation_id) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $delete_sub = sub {
    my $annotation = $schema->resultset('Annotation')->find($annotation_id);
    $annotation->status('deleted');
    $annotation->update();

    _store_suggestion_count($schema);
  };

  $schema->txn_do($delete_sub);

  store_statuses($c->config(), $schema);

  _redirect_and_detach($c);
}

sub annotation_undelete : Chained('top') PathPart('annotation/undelete') Args(1)
{
  my ($self, $c, $annotation_id) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $delete_sub = sub {
    my $annotation = $schema->resultset('Annotation')->find($annotation_id);
    $annotation->status('new');
    $annotation->update();
  };

  $schema->txn_do($delete_sub);

  store_statuses($c->config(), $schema);

  _redirect_and_detach($c);
}

my $iso_date_template = "%4d-%02d-%02d";


sub _get_iso_date
{
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
  return sprintf "$iso_date_template", 1900+$year, $mon+1, $mday
}

sub _get_datetime
{
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
  return sprintf "$iso_date_template %02d:%02d:%02d",
    1900+$year, $mon+1, $mday, $hour, $min, $sec;
}

sub annotation_ontology_edit
{
  my ($self, $c, $gene, $annotation_config) = @_;

  my $module_display_name = $annotation_config->{display_name};

  my $annotation_type_name = $annotation_config->{name};
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $module_category = $annotation_config->{category};

  # don't set stash title - use default
  $st->{current_component} = $annotation_type_name;
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

      _store_suggestion_count($schema);

      $c->flash()->{message} = 'Note that your term suggestion has been '
        . 'stored, but the gene will be temporarily '
        . 'annotated with the parent of your suggested new term';
    }

    my $annotation =
      $schema->create_with_type('Annotation',
                                {
                                  type => $annotation_type_name,
                                  status => 'new',
                                  pub => $st->{pub},
                                  creation_date => _get_iso_date(),
                                  data => { %annotation_data }
                                });

    $annotation->set_genes($gene);

    $guard->commit();

    my $annotation_id = $annotation->annotation_id();
    $_debug_annotation_id = $annotation_id;

    store_statuses($c->config(), $schema);

    _redirect_and_detach($c, 'annotation', 'evidence', $annotation_id);
  }
}

sub annotation_interaction_edit
{
  my ($self, $c, $gene, $annotation_config) = @_;

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

  my $genes_rs = get_ordered_gene_rs($schema, 'primary_name');

  my @options = ();

  while (defined (my $gene = $genes_rs->next())) {
    push @options, { value => $gene->gene_id(),
                     label => $gene->long_display_name() };
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

    $annotation->set_genes($gene);

    $guard->commit();

    my $annotation_id = $annotation->annotation_id();
    $_debug_annotation_id = $annotation_id;

    store_statuses($c->config(), $schema);

    _redirect_and_detach($c, 'annotation', 'evidence', $annotation_id);
  }
}

sub annotation_edit : Chained('top') PathPart('annotation/edit') Args(2) Form
{
  my ($self, $c, $gene_id, $annotation_type_name) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $gene = $schema->find_with_type('Gene', $gene_id);

  $st->{gene} = $gene;

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  my $annotation_display_name = $annotation_config->{display_name};
  my $gene_display_name = $gene->display_name();

  $st->{title} = "Curating $annotation_display_name for $gene_display_name\n";
  $st->{show_title} = 0;

  my %type_dispatch = (
    ontology => \&annotation_ontology_edit,
    interaction => \&annotation_interaction_edit,
  );

  store_statuses($c->config(), $schema);

  &{$type_dispatch{$annotation_config->{category}}}($self, $c, $gene,
                                                    $annotation_config);
}

# redirect to the annotation transfer page only if we've just created an
# ontology annotation and we have more than one gene
sub _maybe_transfer_annotation
{
  my $c = shift;
  my $annotation = shift;
  my $annotation_config = shift;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $gene_count = $schema->resultset('Gene')->count();

  if ($annotation_config->{category} eq 'ontology' && $gene_count > 1) {
    _redirect_and_detach($c, 'annotation', 'transfer',
                         $annotation->annotation_id());
  } else {
    _redirect_and_detach($c);
  }
}

sub annotation_evidence : Chained('top') PathPart('annotation/evidence') Args(1) Form
{
  my ($self, $c, $annotation_id) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $schema->find_with_type('Annotation', $annotation_id);
  my $annotation_type_name = $annotation->type();

  my $gene = $annotation->genes()->first();
  my $gene_display_name = $gene->display_name();

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

  my $ont_config = $config->{annotation_types}->{$annotation_type_name};

  my %evidence_types = %{$config->{evidence_types}};

  my @codes = map {
    my $description;
    if ($evidence_types{$_}->{name} eq $_) {
      $description = $_;
    } else {
      $description = $evidence_types{$_}->{name} . " ($_)";
    }
    [ $_, $description]
  } @{$ont_config->{evidence_codes}};

  unshift @codes, [ '', 'Choose an evidence type ...' ];

  my $form = $self->form();

  my @all_elements = (
      {
        name => 'evidence-select',
        type => 'Select', options => [ @codes ],
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

    $data->{evidence_code} = $evidence_select;

    $annotation->data($data);
    $annotation->update();

    my $with_gene = $evidence_types{$evidence_select}->{with_gene};

    store_statuses($c->config(), $schema);

    if ($with_gene) {
      _redirect_and_detach($c, 'annotation', 'with_gene', $annotation_id);
    } else {
      _maybe_transfer_annotation($c, $annotation, $annotation_config);
    }
  }
}

sub annotation_transfer : Chained('top') PathPart('annotation/transfer') Args(1) Form
{
  my ($self, $c, $annotation_id) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $schema->find_with_type('Annotation', $annotation_id);
  my $annotation_type_name = $annotation->type();

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  $st->{annotation_type} = $annotation_config;
  $st->{annotation} = $annotation;

  my $module_category = $annotation_config->{category};

  my $gene = $annotation->genes()->first();
  my $gene_display_name = $gene->display_name();

  $st->{title} = "Transfer annotation from $gene_display_name";
  $st->{show_title} = 0;
  $st->{template} = "curs/modules/${module_category}_transfer.mhtml";

  my $form = $self->form();

  $form->auto_fieldset(0);

  my $genes_rs = get_ordered_gene_rs($schema, 'primary_name');

  my @options = ();

  while (defined (my $other_gene = $genes_rs->next())) {
    next if $gene->gene_id() == $other_gene->gene_id();

    push @options, { value => $other_gene->gene_id(),
                     label => $other_gene->long_display_name() };
  }

  my @all_elements = (
      {
        type => 'Block',
        tag => 'div',
        content => 'You can annotate other genes from your list with the '
          . 'same term and evidence by selecting genes below',
      },
      {
        name => 'dest', label => 'dest',
        type => 'Checkboxgroup',
        container_tag => 'div',
        label => '',
        options => [@options],
      },
      {
        name => 'transfer-submit', type => 'Submit', value => 'Finish',
      }
    );

  if ($c->user_exists() && $c->user()->role()->name() eq 'admin') {
    my %extension_def = (
      name => 'annotation-extension',
      label => 'Add optional annotation extension',
      type => 'Text',
      container_tag => 'div',
      attributes => { class => 'annotation-extension' },
      size => 60,
    );

    my $existing_extension = $annotation->data()->{annotation_extension};

    if (defined $existing_extension) {
      $extension_def{'value'} = $existing_extension;
    }

    unshift @all_elements, {
      %extension_def,
    };
  }

  $form->elements([@all_elements]);
  $form->process();
  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $submit_value = $form->param_value('transfer-submit');

    my $guard = $schema->txn_scope_guard;

    my @dest_params = @{$form->param_array('dest')};
    my $extension = $form->param_value('annotation-extension');

    my $data = $annotation->data();
    if ($extension && $extension !~ /^\s*$/) {
      $data->{annotation_extension} = $extension;
    }

    $annotation->data($data);
    $annotation->update();

    my $cloned_data = clone $data;
    delete $cloned_data->{with_gene};
    delete $cloned_data->{annotation_extension};

    for my $dest_param (@dest_params) {
      my $dest_gene = $schema->find_with_type('Gene', $dest_param);

      my $new_annotation =
        $schema->create_with_type('Annotation',
                                  {
                                    type => $annotation_type_name,
                                    status => 'new',
                                    pub => $annotation->pub(),
                                    creation_date => _get_iso_date(),
                                    data => $cloned_data,
                                  });
      $new_annotation->set_genes($dest_gene);
    };

    $guard->commit();

    store_statuses($c->config(), $schema);

    _redirect_and_detach($c, 'gene', $gene->gene_id());
  }
}

sub annotation_with_gene : Chained('top') PathPart('annotation/with_gene') Args(1) Form
{
  my ($self, $c, $annotation_id) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $schema->find_with_type('Annotation', $annotation_id);
  my $annotation_type_name = $annotation->type();

  my $gene = $annotation->genes()->first();
  my $gene_display_name = $gene->display_name();

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  my $annotation_data = $annotation->data();
  my $evidence_code = $annotation_data->{evidence_code};
  my $term_ontid = $annotation_data->{term_ontid};

  my $module_category = $annotation_config->{category};

  $st->{title} = "Annotating $gene_display_name";
  $st->{current_component} = $annotation_type_name;
  $st->{current_component_display_name} = $annotation_config->{display_name};
  $st->{template} = "curs/modules/${module_category}_with_gene.mhtml";
  $st->{gene_display_name} = $gene_display_name;

  $st->{term_ontid} = $term_ontid;
  $st->{evidence_code} = $evidence_code;

  my @genes = ();

  my $gene_rs = get_ordered_gene_rs($schema, 'primary_name');

  while (defined (my $gene = $gene_rs->next())) {
    push @genes, [$gene->primary_identifier(), $gene->display_name()];
  }

  unshift @genes, [ '', 'Choose a gene ...' ];

  my $form = $self->form();

  my @all_elements = (
      {
        name => 'with-gene-select',
        type => 'Select', options => [ @genes ],
      },
      {
        name => 'with-gene-proceed', type => 'Submit', value => 'Proceed ->',
      },
    );

  $form->elements([@all_elements]);

  $form->process();

  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $data = $annotation->data();
    my $with_gene_select = $form->param_value('with-gene-select');

    if ($with_gene_select eq '') {
      $c->flash()->{error} = 'Please choose a gene to continue';
      _redirect_and_detach($c, 'annotation', 'with_gene', $annotation_id);
    }

    $data->{with_gene} = $with_gene_select;

    $annotation->data($data);
    $annotation->update();

    _maybe_transfer_annotation($c, $annotation, $annotation_config);
  }

  store_statuses($c->config(), $schema);
}

sub gene : Chained('top') Args(1)
{
  my ($self, $c, $gene_id) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $gene = $schema->find_with_type('Gene', $gene_id);
  $st->{gene} = $gene;

  $st->{title} = 'Gene: ' . $gene->display_name();
  # use only in header, not in body:
  $st->{show_title} = 0;
  $st->{template} = 'curs/gene_page.mhtml';
}

=head2 get_ordered_gene_rs

 Usage   : my $gene_rs = get_ordered_gene_rs($schema, $order_by_field);
 Function: Return an ordered resultset of genes
 Args    : $schema - the CursDB schema
           $order_by_field - the field to order by, defaults to gene_id
 Returns : a ResultSet

=cut
sub get_ordered_gene_rs
{
  my $schema = shift;

  my $order_by_field = shift // 'gene_id';
  my $order_by;

  if ($order_by_field eq 'primary_name') {
    # special case, order by primary_name unless it's null, then use
    # primary_identifier
    $order_by =
      "case when primary_name is null then 'zzz' || primary_identifier " .
      "else primary_name end";
  } else {
    $order_by = {
      -asc => $order_by_field
    }
  }

  return $schema->resultset('Gene')->search({},
                                            {
                                              order_by => $order_by
                                            });
}

sub _get_annotation_table_tsv
{
  my $config = shift;
  my $schema = shift;
  my $annotation_type_name = shift;

  my ($completed_count, $annotations_ref, $columns_ref) =
    PomCur::Curs::Utils::get_annotation_table($config, $schema,
                                              $annotation_type_name);
  my @annotations = @$annotations_ref;
  my %common_values = %{$config->{export}->{gene_association_fields}};

  my $ontology_column_names =
    [qw(db gene_identifier gene_name_or_identifier
        qualifier term_ontid publication_uniquename
        evidence_code with_or_from_identifier
        annotation_type_abbreviation
        gene_product gene_synonyms_string db_object_type taxonid
        creation_date_short db)];

  my $interaction_column_names =
    [qw(gene_identifier interacting_gene_identifier
        gene_taxonid interacting_gene_taxonid evidence_code
        publication_uniquename score phenotypes comment)];

  my %type_column_names = (
    biological_process => $ontology_column_names,
    cellular_component => $ontology_column_names,
    molecular_function => $ontology_column_names,
    phenotype => $ontology_column_names,
    post_translational_modification => $ontology_column_names,
    genetic_interaction => $interaction_column_names,
    physical_interaction => $interaction_column_names,
  );

  my @column_names = @{$type_column_names{$annotation_type_name}};

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
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};
  my $config = $c->config();

  set_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY, _get_datetime());
  store_statuses($c->config(), $schema);

  my $st = $c->stash();

  $st->{title} = 'Finish curation session';
  $st->{show_title} = 0;
  $st->{template} = 'curs/finish_form.mhtml';

  $st->{finish_help} = $c->config()->{messages}->{finish_form};

  my $form = $self->form();
  my @submit_buttons = ("Submit");

  my $finish_textarea = 'finish_textarea';

  my @all_elements = (
      { name => $finish_textarea, type => 'Textarea', cols => 80, rows => 20
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
    my $text = $form->param_value($finish_textarea);
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;

    set_metadata($schema, MESSAGE_FOR_CURATORS_KEY, $text);

    _redirect_and_detach($c, 'finished_publication');
  }
}

sub finished_publication : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Finished publication';
  $st->{show_title} = 0;
  $st->{template} = 'curs/finished_publication.mhtml';
}

sub reactivate_session : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};

  my $proc = sub {
    unset_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY);
    unset_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY);
    unset_metadata($schema, APPROVED_TIMESTAMP_KEY);
    store_statuses($c->config(), $schema);
  };

  $schema->txn_do($proc);

  $c->flash()->{message} = 'Session has been reactivated';

  _redirect_and_detach($c);
}

sub check_session : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};

  my $proc = sub {
    if (!defined get_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY)) {
      set_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY, _get_datetime());
    }
    set_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY, _get_datetime());
    unset_metadata($schema, APPROVED_TIMESTAMP_KEY);
  };

  $schema->txn_do($proc);

  store_statuses($c->config(), $schema);

  _redirect_and_detach($c);
}

sub check_completed : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};

  set_metadata($schema, APPROVED_TIMESTAMP_KEY, _get_datetime());
  store_statuses($c->config(), $schema);

  $c->flash()->{message} = 'Session approved';

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
