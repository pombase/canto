package Canto::Curs::TermUpdate;

=head1 NAME

Canto::Curs::TermUpdate - Code for updating existing terms in the
                           Curs DBs after an ontology has been updated

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::TermUpdate

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Moose;

use Canto::Curs::MetadataStorer;

with 'Canto::Role::Configurable';

has config => (is => 'ro', isa => 'Canto::Config',
               required => 1);

has metadata_storer => (is => 'ro', init_arg => undef,
                        isa => 'Canto::Curs::MetadataStorer',
                        lazy_build => 1);

sub _build_metadata_storer
{
  my $self = shift;
  my $storer = Canto::Curs::MetadataStorer->new(config => $self->config());

  return $storer;
}

sub update_curs_terms
{
  my ($self, $curs, $cursdb) = @_;

  my $config = $self->config();
  my $lookup = Canto::Track::get_adaptor($config, 'ontology');

  my $annotation_rs = $cursdb->resultset('Annotation');

  while (defined (my $annotation = $annotation_rs->next())) {
    my $data = $annotation->data();

    if (defined $data->{conditions}) {
      my $changed = 0;

      # replace term names with the ID if we know it otherwise assume that the
      # user has made up a condition
      map { my $name = $_;
            my $res = $lookup->lookup_by_name(ontology_name => 'phenotype_condition',
                                              term_name => $name);
            if (defined $res) {
              $_ = $res->{id};
              $changed = 1;
            }
          } @{$data->{conditions}};

      if ($changed) {
        $annotation->data($data);
        $annotation->update();
      }
    }
  }

  $self->metadata_storer()->store_counts($cursdb);
}

1;
