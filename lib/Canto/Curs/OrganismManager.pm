package Canto::Curs::OrganismManager;

=head1 NAME

Canto::Curs::OrganismManager - Manage adding and removing session organism

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::OrganismManager

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

use Canto::Track;
use Canto::CursDB::Organism;

use Canto::Curs::StrainManager;

has curs_schema => (is => 'rw', isa => 'Canto::CursDB', required => 1);
has organism_lookup => (is => 'ro', init_arg => undef, lazy_build => 1);
has strain_manager => (is => 'ro', init_arg => undef, lazy_build => 1);

with 'Canto::Role::Configurable';

sub _build_organism_lookup
{
  my $self = shift;

  return Canto::Track::get_adaptor($self->config(), 'organism');
}

sub _build_strain_manager
{
  my $self = shift;

  return Canto::Curs::StrainManager->new(config => $self->config(),
                                         curs_schema => $self->curs_schema());
}

=head2 add_organism_by_taxonid

 Usage   : $organism_manager->add_organism_by_taxonid($taxonid);
 Function: add the organism with the given taxon ID to the session
 Returns : the new Organism in the CursDB or undef if the $taxonid is not in
           the TrackDB

=cut


sub add_organism_by_taxonid
{
  my $self = shift;

  my $taxonid = shift;

  if (!defined $taxonid) {
    croak "no taxon ID passed to OrganismManager::add_organism_by_taxonid()\n";
  }

  my $organism_details = $self->organism_lookup->lookup_by_taxonid($taxonid);

  if ($organism_details) {
    return Canto::CursDB::Organism::get_organism($self->curs_schema(), $taxonid);
  } else {
    return undef;
  }
}

sub delete_organism_by_taxonid
{
  my $self = shift;

  my $taxonid = shift;

  my $organism_rs = $self->curs_schema()->resultset('Organism');

  my $organism = $organism_rs->find({ taxonid => $taxonid });

  if ($organism) {
    if ($organism->genes()->count() > 0) {
      die "can't delete organism with taxonid $taxonid as there are genes " .
        "from that organism in the session\n";
    } else {
      $self->strain_manager()->delete_strains_by_taxon_id($taxonid);
      $organism_rs->search({ taxonid => $taxonid })->delete();
      return $organism;
    }
  } else {
    die "can't find organism with taxonid $taxonid\n"
  }
}

1;
