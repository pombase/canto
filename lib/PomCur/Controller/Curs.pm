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

use strict;
use warnings;
use Carp;

use PomCur::Curs::Util;
use PomCur::Track;

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

  my %annotation_modules = %{$config->{annotation_modules}};

  @{$st->{module_names}} = keys %annotation_modules;

  my $schema = PomCur::Curs::get_schema($c);

  $st->{schema} = $schema;

  my $submitter_email =
    $schema->resultset('Metadata')->find({ key => 'submitter_email' });

  my $first_contact_email =
    $schema->find_with_type('Metadata', { key => 'first_contact_email' });
  $st->{first_contact_email} = $first_contact_email->value();

  my $first_contact_name =
    $schema->find_with_type('Metadata', { key => 'first_contact_name' });
  $st->{first_contact_name} = $first_contact_name->value();

  if (defined $submitter_email) {
    $st->{submitter_email} = $submitter_email->value();

    my $submitter_name =
      $schema->resultset('Metadata')->find({ key => 'submitter_name' });
    $st->{submitter_name} = $submitter_name->value();

    my $pub_title =
      $schema->find_with_type('Metadata', { key => 'pub_title' })->value();
    $st->{pub_title} = $pub_title;

    $st->{curs_initialised} = 1;
  } else {
    $st->{curs_initialised} = 0;
    if ($path !~ /submitter_update/) {
      $c->res->redirect($st->{curs_root_path} . '/submitter_update');
      $c->detach();
    }
  }
}

sub _redirect_home_and_detach
{
  my ($self, $c) = @_;

  $c->res->redirect($c->stash->{curs_root_path} . '/home');
  $c->detach();
}

sub home_redirect : Chained('top') PathPart('') Args(0)
{
  my ($self, $c) = @_;

  $self->_redirect_home_and_detach($c);
}

sub home : Chained('top') PathPart('home') Args(0)
{
  my ($self, $c) = @_;

  $c->stash->{title} = 'Home';
  $c->stash->{template} = 'curs/home.mhtml';

  $c->stash->{current_component} = 'home';
}

sub submitter_update : Chained('top') PathPart('submitter_update') Args(0)
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
      {
        name => 'continue', type => 'Submit', value => 'continue',
        attributes => { class => 'button', },
      }
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

  my @gene_primary_identifiers = map { $_->primary_identifier() } @genes;

  my $gene_rs = $schema->resultset('Gene');
  my $rs = $gene_rs->search({
    primary_identifier => {
      -in => [@gene_primary_identifiers],
    }
  });

  my %found_genes = ();
  while (defined (my $gene = $rs->next())) {
    $found_genes{$gene->primary_identifier()} = 1;
  }

  return grep { !exists $found_genes{ $_->primary_identifier()} } @genes;
}

sub _find_and_create_genes
{
  my ($schema, $config, $search_terms_ref) = @_;

  my @search_terms = @$search_terms_ref;
  my $store = PomCur::Track::get_store($config, 'gene');

  my $result = $store->lookup([@search_terms]);

  if (@{$result->{missing}}) {
    return $result;
  } else {
    my $_create_curs_genes = sub
        {
          my @genes = @{$result->{found}};

          @genes = _filter_existing_genes($schema, @genes);

          for my $gene (@genes) {
            my $org_full_name = $gene->organism()->full_name();
            my $curs_org =
              PomCur::CursDB::Organism::get_organism($schema, $org_full_name);

            $schema->create_with_type('Gene', {
              primary_name => $gene->primary_name(),
              primary_identifier => $gene->primary_identifier(),
              product => $gene->product(),
              organism => $curs_org
            });
          }
        };

    $schema->txn_do($_create_curs_genes);

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

  my @all_elements = (
      { name => $gene_list_textarea_name, type => 'Textarea', cols => 80, rows => 10,
        constraints => [ { type => 'Length',  min => 1 }, 'Required' ],
      },
      map {
          {
            name => $_, type => 'Submit', value => $_,
              attributes => { class => 'button', },
            }
        } qw(submit cancel),
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

    my $schema = PomCur::Curs::get_schema($c);

    my $result = _find_and_create_genes($schema, $c->config(), \@search_terms);

    if ($result) {
      my @missing = @{$result->{missing}};
      $st->{error} =
          { title => "No genes found for these identifiers: @missing" };
      $st->{gene_upload_unknown} = [@missing];
    } else {
      $self->_redirect_home_and_detach($c);
    }
  }
}

sub module_dispatch : Chained('top') PathPart('') Args(1)
{
  my ($self, $c, $module_name) = @_;

  my $config = $c->config();

  my $st = $c->stash();

  my $module_display_name =
    PomCur::Curs::Util::module_display_name($module_name);
  $st->{title} = 'Module: ' . $module_display_name;
  $st->{current_component} = $module_name;
  $st->{template} = "curs/modules/$module_name.mhtml";

  my %annotation_modules = %{$config->{annotation_modules}};

  my $module_config = $annotation_modules{$module_name};
  my $module_class_name = $module_config->{class};

  my %args = (config => $config);

  while (my($key, $value) = each %{$module_config->{constructor_args}}) {
    $args{$key} = $value;
  }

  eval "use $module_class_name";
  if ($@) {
    die "can't find module ('$module_class_name') specified in configuration "
      . "for module: $module_name\n";
  }

  my $store = $module_class_name->new(%args);

}

1;
