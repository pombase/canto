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

=head2 rename_strain

 Usage   : $track_util->rename_strain($taxonid, $old_name, $new_name);
 Function: Rename a strain of the organism given by $taxonid, fails if there
           is no strain with $old_name or there is an existing strain with
           $new_name.
 Args    : $old_name
           $new_name
 Returns : nothing

=cut

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

sub _find_used_strains
{
  my $self = shift;

  my $track_schema = $self->schema();

  my %used_strain_ids = ();

  my $proc = sub {
    my $curs = shift;
    my $cursdb = shift;

    my $rs = $cursdb->resultset('Strain');

    while (defined (my $strain = $rs->next())) {
      my $track_strain_id = $strain->track_strain_id();

      if (defined $track_strain_id) {
        $used_strain_ids{$track_strain_id} = 1;
      }
    }
  };

  Canto::Track::curs_map($self->config(), $track_schema, $proc);

  return %used_strain_ids;
}

=head2 delete_unused_strains

 Usage   : $track_util->delete_unused_strains();
 Function: Delete all strains that aren't used in a session.
 Args    : None
 Returns : The number of strains deleted

=cut

sub delete_unused_strains
{
  my $self = shift;

  my $track_schema = $self->schema();

  my %used_strain_ids = $self->_find_used_strains();

  my $count = 0;

  my $rs = $track_schema->resultset('Strain');

  while (defined (my $strain = $rs->next())) {
    if (!exists $used_strain_ids{$strain->strain_id()}) {
      $strain->delete();
      $count++;
    }
  }

  return $count;
}

1;
