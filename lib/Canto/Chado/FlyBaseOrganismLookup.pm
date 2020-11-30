package Canto::Chado::FlyBaseOrganismLookup;

=head1 NAME

Canto::Chado::FlyBaseOrganismLookup - Lookup organisms using FlyBase Chado

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Chado::FlyBaseOrganismLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;

use Canto::Curs::Utils;

with 'Canto::Role::Configurable';
with 'Canto::Chado::ChadoLookup';

our $cache = {};


=head2 lookup_by_type()

 Usage   : my $lookup = Canto::Track::get_adaptor($config, 'organism');
           my $organism = $lookup->lookup_by_taxonid(4896);
 Function: Retrieve an organism by taxon id from the TrackDB
 Return  : A hash of organism details in the format:
           { scientific_name => '...', taxon_id => '...',
             pathogen_or_host => 'host' }

=cut
sub lookup_by_taxonid
{
  my $self = shift;
  my $taxon_id = shift;

  if (!defined $taxon_id) {
    croak "no taxon ID passed to OrganismLookup::lookup_by_taxonid()\n";
  }

  if (exists $cache->{$taxon_id}) {
    return $cache->{$taxon_id};
  }

  my $schema = $self->schema();
  my $config = $self->config();

  my $organism_rs = $schema->resultset('Organism')
    ->search({ },
             {
               where => \qq|organism_id in (select organism_id from organism_dbxref org_xref
       JOIN dbxref xref ON org_xref.dbxref_id = xref.dbxref_id
       JOIN db ON db.db_id = xref.db_id
       WHERE db.name = 'NCBITaxon'
          AND xref.accession = ?)|,
               bind => [ $taxon_id ]
             });

  my $organism = $organism_rs->first();

  if ($organism) {
    my $scientific_name = $organism->genus() . ' ' . $organism->species();
    $cache->{$taxon_id} = {
      scientific_name => $scientific_name,
      full_name => $scientific_name,
      common_name => $organism->common_name(),
      taxonid => $taxon_id,
      pathogen_or_host => 'unknown',
    };
    return $cache->{$taxon_id};
  } else {
    return undef;
  }
}

1;
