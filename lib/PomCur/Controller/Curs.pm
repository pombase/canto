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

use PomCur::Curs::Util;
use PomCur::Track;

use constant {
  # user needs to confirm name and email address
  NEEDS_SUBMITTER => 0,
  # no genes in database, user needs to upload some
  NEEDS_GENES => 1,
#  READY => 2,
  # a gene is selected, but no annotation is started
  GENE_ACTIVE => 3,
  # user has picked an annotation type
  ANNOTATION_ACTIVE => 4,
  # all genes have some annotatation, but user can select a gene and
  # do some more annotation
  DONE => 5
};

# actions to execute for each state, undef for special cases
my %state_dispatch = (
  NEEDS_SUBMITTER, 'submitter_update',
  NEEDS_GENES, 'gene_upload',
  GENE_ACTIVE, undef,
  ANNOTATION_ACTIVE, undef,
  DONE, 'home',
);

=head2 begin

 Action to set up stash contents for curs

=cut
sub top : Chained('/') PathPart('curs') CaptureArgs(1)
{
  my ($self, $c, $curs_key) = @_;

  my $st = $c->stash();

  $st->{curs_key} = $curs_key;

  my $path = $c->req->uri()->path();
  (my $controller_name = __PACKAGE__) =~ s/.*::(.*)/\L$1/;
  $st->{controller_name} = $controller_name;

  my $root_path = $c->uri_for("/$controller_name/$curs_key");
  $st->{curs_root_path} = $root_path;

  my $config = $c->config();
  my %annotation_types = %{$config->{annotation_types}};

  @{$st->{annotation_type_names}} = keys %annotation_types;

  my $schema = PomCur::Curs::get_schema($c);
  $st->{schema} = $schema;

  my ($state, $submitter_email,
      $gene_count, $current_gene_id, $current_annotation_id) = _get_state($c);
  $st->{state} = $state;

  $st->{first_contact_email} = get_metadata($schema, 'first_contact_email');
  $st->{first_contact_name} = get_metadata($schema, 'first_contact_name');

  my $pub_id = get_metadata($schema, 'curation_pub_id');
  $st->{pub} = $schema->find_with_type('Pub', $pub_id);

  if ($state >= NEEDS_GENES) {
    $st->{submitter_email} = $submitter_email;
    $st->{submitter_name} = get_metadata($schema, 'submitter_name');
  }

  if ($state == GENE_ACTIVE) {
    $st->{current_gene_id} = $current_gene_id;
    $st->{current_gene} = $schema->find_with_type('Gene', $current_gene_id);
  }
  if ($state == ANNOTATION_ACTIVE) {
    $st->{current_annotation_id} = $current_annotation_id;
    my $current_annotation =
      $schema->find_with_type('Annotation', $current_annotation_id);
    $st->{current_annotation} = $current_annotation;
    my $current_gene_id = $current_annotation->data()->{gene_id};
    $st->{current_gene_id} = $current_gene_id;
    $st->{current_gene} = $schema->find_with_type('Gene', $current_gene_id);

    $st->{current_annotation_type} = $current_annotation->type();
  }

  $st->{gene_count} = _get_gene_resultset($schema)->count();

  if ($path !~ /gene_upload|edit_genes/) {
    my $dispatch_dest = $state_dispatch{$state};
    if (defined $dispatch_dest) {
      $c->detach($dispatch_dest);
    } else {
      if ($current_annotation_id) {
        # choose a module based by looking in the current annotation
        my $current_annotation =
          $schema->resultset('Annotation')->find($current_annotation_id);
        $c->detach('annotation_dispatch', [$current_annotation->type()]);
      }
    }
  }
}

# Return a constant describing the state of the application, eg. NEEDS_GENES
# or DONE.  See the %state hash above for details
sub _get_state
{
  my $c = shift;

  my $st = $c->stash();

  my $schema = $st->{schema};
  my $submitter_email = get_metadata($schema, 'submitter_email');

  my $state = undef;
  my $current_annotation_id = undef;
  my $current_gene_id = undef;
  my $gene_count = undef;

  if (defined $submitter_email) {
    my $gene_rs = _get_gene_resultset($schema);
    $gene_count = $gene_rs->count();

    if ($gene_count > 0) {
      $current_annotation_id = get_metadata($schema, 'current_annotation_id');
      $current_gene_id = get_metadata($schema, 'current_gene_id');

      if (defined $current_gene_id) {
        if (defined $current_annotation_id) {
          die 'internal error - ' .
            'current_gene_id and current_annotation_id are both set';
        } else {
          $state = GENE_ACTIVE;
        }
      } else {
        if (defined $current_annotation_id) {
          $state = ANNOTATION_ACTIVE;
        } else {
          $state = DONE;
        }
      }
    } else {
      $state = NEEDS_GENES;
    }
  } else {
    $state = NEEDS_SUBMITTER;
  }

  return ($state, $submitter_email, $gene_count,
          $current_gene_id, $current_annotation_id);
}

sub _set_new_gene
{
  my $c = shift;
  my $schema = $c->stash->{schema};

  my $gene_rs = _get_gene_resultset($schema);
  my $first_gene = $gene_rs->first();

  if (defined get_metadata($schema, 'current_gene_id') ||
      defined get_metadata($schema, 'current_annotation_id')) {
    die 'internal error - ' .
      'current_gene_id and current_annotation_id are both set';
  }

  set_metadata($schema, 'current_gene_id', $first_gene->gene_id());
  $c->stash()->{state} = GENE_ACTIVE;
}

sub _redirect_home_and_detach
{
  my ($self, $c) = @_;

  $c->res->redirect($c->stash->{curs_root_path});
  $c->detach();
}

sub home : Chained('top') PathPart('') Args(0)
{
  my ($self, $c) = @_;

  $c->stash->{title} = 'Home';
  $c->stash->{template} = 'curs/home.mhtml';

  $c->stash->{current_component} = 'home';
}

sub submitter_update : Private
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Submitter update';
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
        name => 'submit', type => 'Submit', value => 'submit',
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

    $self->_redirect_home_and_detach($c);
  }
}

my $gene_list_textarea_name = 'gene_identifiers';

# return a list of only those genes which aren't already in the database
sub _filter_existing_genes
{
  my $schema = shift;
  my @genes = @_;

  my @gene_primary_identifiers = map { $_->{primary_identifier} } @genes;

  my $gene_rs = _get_gene_resultset($schema);
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

sub _create_gene
{
  my $schema = shift;
  my $result = shift;

  my $ret_gene = undef;

  my $_create_curs_genes = sub
      {
        my @genes = @{$result->{found}};

        @genes = _filter_existing_genes($schema, @genes);

        for my $gene (@genes) {
          my $org_full_name = $gene->{organism_full_name};
          my $curs_org =
            PomCur::CursDB::Organism::get_organism($schema, $org_full_name);

          $ret_gene = $schema->create_with_type('Gene', {
            primary_name => $gene->{primary_name},
            primary_identifier => $gene->{primary_identifier},
            product => $gene->{product},
            organism => $curs_org
          });
        }
      };

  $schema->txn_do($_create_curs_genes);

  return $ret_gene;
}

sub _find_and_create_genes
{
  my ($schema, $config, $search_terms_ref) = @_;

  my @search_terms = @$search_terms_ref;
  my $lookup = PomCur::Track::get_lookup($config, $schema, 'gene');

  my $result = $lookup->lookup([@search_terms]);

  if (@{$result->{missing}}) {
    return $result;
  } else {
    _create_gene($schema, $result);

    return undef;
  }
}

sub edit_genes : Chained('top') Args(0) Form
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Edit gene list';
  $st->{template} = 'curs/gene_list.mhtml';

  $st->{current_component} = 'list_edit';

  $st->{big_list} = 1;
}

sub gene_upload : Chained('top') Args(0) Form
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Gene upload';
  $st->{template} = 'curs/gene_upload.mhtml';
  $st->{current_component} = 'gene_upload';

  my $form = $self->form();
  my @submit_buttons = ("submit");

  my $schema = $st->{schema};

  if ($st->{gene_count} > 0) {
    push @submit_buttons, "cancel";
  }

  my @all_elements = (
      { name => $gene_list_textarea_name, type => 'Textarea', cols => 80, rows => 10,
        constraints => [ { type => 'Length',  min => 1 }, 'Required' ],
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

  if ($form->submitted()) {
    if (defined $c->req->param('cancel')) {
      $self->_redirect_home_and_detach($c);
    }
  }

  if ($form->submitted_and_valid()) {
    my $search_terms_text = $form->param_value($gene_list_textarea_name);
    my @search_terms = grep { length $_ > 0 } split /[\s,]+/, $search_terms_text;

    my $result = _find_and_create_genes($schema, $c->config(), \@search_terms);

    if ($result) {
      my @missing = @{$result->{missing}};
      $st->{error} =
          { title => "No genes found for these identifiers: @missing" };
      $st->{gene_upload_unknown} = [@missing];
    } else {
      my $state = $st->{state};
      if ($state ne GENE_ACTIVE && $state ne ANNOTATION_ACTIVE) {
        _set_new_gene($c);
      }
      $self->_redirect_home_and_detach($c);
    }
  }
}

sub _get_annotation_helper
{
  my $c = shift;
  my $annotation_type_name = shift;

  my $config = $c->config();
  my $st = $c->stash();

  my %annotation_types = %{$config->{annotation_types}};

  my $module_config = $annotation_types{$annotation_type_name};
  my $module_class_name = $module_config->{class};

  my %args = (config => $config);

  while (my($key, $value) = each %{$module_config->{constructor_args}}) {
    $args{$key} = $value;
  }

  eval "use $module_class_name";
  if ($@) {
    die "can't find module ('$module_class_name') specified in configuration "
      . "for module: $annotation_type_name\n";
  }

  my $lookup = $module_class_name->new(%args);

}

sub annotation_choose : Chained('top') PathPart('') Args(1)
{
  my ($self, $c, $annotation_type_name) = @_;

  my $schema = $c->stash()->{schema};

  my $process = sub {
    my $current_gene_id = $c->stash()->{current_gene_id};
    my $annotation =
      $schema->create_with_type('Annotation', { type => $annotation_type_name,
                                                status => 'new',
                                                data => {
                                                  gene_id => $current_gene_id
                                                }
                                              });

    set_metadata($schema, 'current_annotation_id',
                  $annotation->annotation_id());
    # the gene is stored in the annotation, so unset
    set_metadata($schema, 'current_gene_id', undef);
  };

  $schema->txn_do($process);

  $c->dispatch('annotation_dispatch', $annotation_type_name);
}

sub annotation_dispatch : Private
{
  my ($self, $c, $annotation_type_name) = @_;

  my $config = $c->config();
  my $st = $c->stash();

  my $module_display_name =
    PomCur::Curs::Util::module_display_name($annotation_type_name);
  $st->{title} = 'Module: ' . $module_display_name;
  $st->{current_component} = $annotation_type_name;
  $st->{template} = "curs/modules/$annotation_type_name.mhtml";

  my $annotation_helper = _get_annotation_helper($c, $annotation_type_name);

  $st->{annotation_helper} = $annotation_helper;
}

sub _get_gene_resultset
{
  my $schema = shift;
  return $schema->resultset('Gene')->search({},
                                            {
                                              order_by => {
                                                -asc => 'gene_id'
                                              }
                                            });
}

1;
