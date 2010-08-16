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

  $c->stash()->{curs_key} = $curs_key;

  my $path = $c->req->uri()->path();
  (my $controller_name = __PACKAGE__) =~ s/.*::(.*)/\L$1/;
  $c->stash->{controller_name} = $controller_name;

  my $root_path = $c->uri_for("/$controller_name/$curs_key");
  $c->stash->{curs_root_path} = $root_path;

  my $config = $c->config();

  my %annotation_modules = %{$config->{annotation_modules}};

  @{$c->stash->{module_names}} = keys %annotation_modules;
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

  $c->stash->{component} = 'home';
}

my $gene_list_textarea_name = 'gene_identifiers';


sub _find_and_create_genes
{
  my ($self, $c, $form) = @_;

  my $gene_list = $form->param_value($gene_list_textarea_name);
  my $schema = PomCur::Curs::get_schema($c);
  my $store = PomCur::Track::get_store($c->config(), 'gene');
  my @search_terms = grep { length $_ > 0 } split /[\s,]+/, $gene_list;

  my $result = $store->lookup([@search_terms]);

  if (@{$result->{missing}}) {
    return $result;
  } else {
    my $_create_curs_genes = sub
        {
          my @genes = @{$result->{found}};

          for my $gene (@genes) {
            $schema->create_with_type('Gene', {
              primary_name => $gene->{primary_name},
              primary_identifier => $gene->{primary_identifier},
              product => $gene->{product},
              organism => 1,  # FIXME - don't hard-code this
            });
          }
        };

    $schema->txn_do($_create_curs_genes);

    return undef;
  }
}

sub gene_upload : Chained('top') Args(0) Form
{
  my ($self, $c) = @_;

  $c->stash->{title} = 'Gene upload';
  $c->stash->{template} = 'curs/gene_upload.mhtml';

  $c->stash->{component} = 'gene_upload';

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

  $form->auto_fieldset(1);

  $form->elements([@all_elements]);

  $form->process();

  $c->stash->{form} = $form;

  if ($form->submitted()) {
    if (defined $c->req->param('cancel')) {
      $self->_redirect_home_and_detach($c);
    }
  }

  if ($form->submitted_and_valid()) {
    my $result = $self->_find_and_create_genes($c, $form);

    if ($result) {
      my @missing = @{$result->{missing}};
      $c->stash->{error} =
          { title => "No genes found for these identifiers: @missing" };
      $c->stash->{gene_upload_unknown} = [@missing];
    } else {
      $self->_redirect_home_and_detach($c);
    }
  }
}

sub module_dispatch : Chained('top') PathPart('') Args(1)
{
  my ($self, $c, $module_name) = @_;

  my $config = $c->config();

  my $module_display_name =
    PomCur::Curs::Util::module_display_name($module_name);
  $c->stash->{title} = 'Module: ' . $module_display_name;
  $c->stash->{component} = $module_name;
  $c->stash->{template} = "curs/modules/$module_name.mhtml";

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
