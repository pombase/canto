package Canto::Curs::StrainManager;

=head1 NAME

Canto::Curs::StrainManager - Manage strains in a session

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::StrainManager

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2018 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

use Canto::Track;
use Canto::CursDB::Organism;

has curs_schema => (is => 'rw', isa => 'Canto::CursDB', required => 1);
has strain_lookup => (is => 'ro', init_arg => undef, lazy_build => 1);
has organism_manager => (is => 'ro', init_arg => undef, lazy_build => 1);

with 'Canto::Role::Configurable';

sub _build_strain_lookup
{
  my $self = shift;

  return Canto::Track::get_adaptor($self->config(), 'strain');
}

sub _build_organism_manager
{
  my $self = shift;

  return Canto::Curs::OrganismManager->new(config => $self->config(),
                                           curs_schema => $self->curs_schema());
}

=head2 add_strain_by_id

 Usage   : $strain_manager->add_strain_by_id($strain_id);
 Function: Adds the given strain to the current session
 Returns : Nothing

=cut

sub add_strain_by_id
{
  my $self = shift;

  my $track_strain_id = shift;

  my $curs_schema = $self->curs_schema();
  my $strain_rs = $curs_schema->resultset('Strain');

  my $strain = $strain_rs->find({ track_strain_id => $track_strain_id });

  if ($strain) {
    return $strain;
  } else {
    my @track_strain_details =
      $self->strain_lookup()->lookup_by_strain_ids($track_strain_id);

    my $taxon_id = $track_strain_details[0]->{taxon_id};

    my $organism = $self->organism_manager()->add_organism_by_taxonid($taxon_id);

    return $curs_schema->create_with_type('Strain',
                                          {
                                            track_strain_id => $track_strain_id,
                                            organism_id => $organism->organism_id(),
                                          });
  }
}


=head2 delete_strain_by_id

 Usage   : $strain_manager->delete_strain_by_id($strain_id);
 Function: Delete a strain using its strain ID from the TrackDB
 Returns : The deleted strain but dies if the strain is referenced by any
           genotypes

=cut

sub delete_strain_by_id
{
  my $self = shift;

  my $track_strain_id = shift;

  my $strain_rs = $self->curs_schema()->resultset('Strain');

  my $strain = $strain_rs->find({ track_strain_id => $track_strain_id });

  if ($strain) {
    if ($strain->genotypes()->count() > 0) {
      die "can't delete strain with ID $track_strain_id as there are genotypes " .
        "in the session that reference that strain\n";
    } else {
      $strain->delete();
      return $strain;
    }
  } else {
    die "can't find strain with ID $track_strain_id\n"
  }
}


=head2 delete_strain_by_name

 Usage   : $strain_manager->delete_strain_by_name($strain_name);
 Function: Delete a strain using its strain ID from the TrackDB
 Returns : The deleted strain but dies if the strain is referenced by any
           genotypes

=cut

sub delete_strain_by_name
{
  my $self = shift;

  my $strain_name = shift;

  my $strain_rs = $self->curs_schema()->resultset('Strain');

  my $strain = $strain_rs->find({ strain_name => $strain_name });

  if (!$strain) {
    my $track_strain_details =
      $self->strain_lookup()->lookup_by_strain_name($strain_name);

    if ($track_strain_details) {
      $strain = $strain_rs->find({
        strain_name => $track_strain_details->{strain_name},
      });
    }
  }

  if ($strain) {
    if ($strain->genotypes()->count() > 0) {
      die "can't delete strain with name $strain_name as there are genotypes " .
        "in the session that reference that strain\n";
    } else {
      $strain->delete();
      return $strain;
    }
  } else {
    die "can't find strain with name $strain_name\n"
  }
}


1;
