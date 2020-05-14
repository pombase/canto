package Canto::Track::TrackUtil;

=head1 NAME

Canto::Track::TrackUtil - Miscellaneous utility functions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::TrackUtil

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;

use Moose;

use Canto::TrackDB;

with 'Canto::Role::Configurable';
with 'Canto::Track::Role::Schema';

sub _get_strain_rs
{
  my $schema = shift;
  my $taxonid = shift;
  my $strain_name = shift;

  return $schema->resultset('Strain')
    ->search({
      'type.name' => 'taxon_id', 'organismprops.value' => $taxonid,
      'me.strain_name' => $strain_name,
    },
    {
      join => { organism => { organismprops => 'type' } }
    });
}

sub rename_strain
{
  my $self = shift;

  my $taxonid = shift;
  my $old_name = shift;
  my $new_name = shift;

  my $schema = $self->schema();

  my $existing_old_rs = _get_strain_rs($schema, $taxonid, $old_name);

  if ($existing_old_rs->count() == 0) {
    die qq|no existing strain found with name "$old_name" for taxon "$taxonid"\n|;
  }

  if ($existing_old_rs->count() > 1) {
    die qq|two or more existing strains found with name "$old_name" for taxon "$taxonid"\n|;
  }

  my $existing_new_rs = _get_strain_rs($schema, $taxonid, $new_name);

  if ($existing_new_rs->count() > 0) {
    die qq|can't rename strain "$old_name" to "$new_name" - a strain with name | .
      qq|"$new_name" already exists for taxon "$taxonid"\n|;
  }

  my $existing_strain = $existing_old_rs->first();

  $existing_strain->strain_name($new_name);
  $existing_strain->update();
}

1;
