package Canto::Role::TaxonIDLookup;

=head1 NAME

Canto::Role::TaxonIDLookup - Get a taxon ID for an organism, from the database
                             or from the configuration file

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Role::TaxonIDLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose::Role;

requires 'config';
requires 'schema';

=head2 taxon_id_lookup

 Usage   : my $taxonid = $self->taxon_id_lookup($organism);
 Function: Return the NCBI taxon ID of the Organism by querying the database
           or looking in the configuration file (see "organism_taxon_id").

 If the organism_taxon_id configuration is set, that will be used.  Example:
 organism_taxon_id:
   'Schizosaccharomyces pombe': 4896

 If organism_taxon_id is not set, look for the taxon ID as an organismprop
 with type "taxon_id".

 If that fails, dies with an error.

=cut

sub taxon_id_lookup
{
  my $self = shift;

  my $organism = shift;

  my $taxonid;

  if (exists $self->config()->{organism_taxon_id}) {
    my $scientific_name = $organism->scientific_name();
    $taxonid = $self->config()->{organism_taxon_id}->{$scientific_name};

    if (!defined $taxonid) {
      croak "no configuration in 'organism_taxon_id' for ",
        $organism->full_name(), "\n";
    }
  } else {
    my $lookup_strategy = $self->config()->{chado}->{taxon_id_lookup_strategy} || 'organismprop';

    if ($lookup_strategy eq 'organismprop') {
      $taxonid = $self->{_taxonid_cache}->{$organism->full_name()};
      if (!defined $taxonid) {
        my $prop = $organism->organismprops()
          ->search({ 'type.name' => 'taxon_id' }, { join => 'type' })->first();
        if (!defined $prop) {
          croak "no 'organism_taxon_id' configuration found and no 'taxon_id' ",
            "organismprop found for ", $organism->full_name();
        }
        $taxonid = $prop->value();
        $self->{_taxonid_cache}->{$organism->full_name()} = $taxonid;
      }
    } else {
      if ($lookup_strategy eq 'dbxref') {

        my $chado_dbh = $self->schema()->storage()->dbh();
        my $sth = $chado_dbh->prepare(<<'EOF');
SELECT dbxref.accession
FROM organism_dbxref
JOIN dbxref ON organism_dbxref.dbxref_id = dbxref.dbxref_id
JOIN db ON dbxref.db_id = db.db_id
WHERE organism_dbxref.is_current = 't'
  AND db.name = 'NCBITaxon'
  AND organism_dbxref.organism_id = ?;
EOF

        $sth->execute($organism->organism_id());

        while (my ($taxon_accession) = $sth->fetchrow_array()) {
          $taxonid = $taxon_accession;
          last;
        }
      } else {
        die "unknown taxon_id_lookup_strategy: $lookup_strategy";
      }
    }
  }

  return $taxonid
}

1;
