package Canto::Chado::FeaturePubLookup;

=head1 NAME

Canto::Chado::FeaturePubLookup - Look up publication to feature relations and
                                 sources in Chado

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Chado::FeaturePubLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2024 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use feature qw(state);

use Moose;

use Canto::Curs::Utils;

with 'Canto::Role::Configurable';
with 'Canto::Chado::ChadoLookup';


=head2 lookup

 Usage   : my $feature_pub_lookup = Canto::Track::get_adaptor($config, 'feature_pub');
           my $results = $allele_lookup->lookup(publication_uniquename => 'PMID:31563844',
                                                feature_type => 'gene')
 Function: Look up the features and feature_pub_source props in Chado
 Args    : publication_uniquename - a PMID
           feature_type - a SO term name
 Return  : [ { gene_uniquename => 'SPBC685.02'
               gene_name => 'exo5',
               feature_pub_source => 'contig_file_dbxref' }
             { ... },
             ...
           ]
=cut

sub lookup
{
  my $self = shift;

  my %args = @_;

  my $publication_uniquename = $args{publication_uniquename};

  if (!defined $publication_uniquename) {
    die "no publication_uniquename passed to lookup()";
  }

  my $feature_type = $args{feature_type};
  if (!defined $feature_type) {
    die "no feature_type parameter passed to lookup()";
  }

  my $schema = $self->schema();

  my $chado_dbh = $schema->storage()->dbh();

  my $query = <<'EOQ';
SELECT f.uniquename AS gene_uniquename,
       f.name AS gene_name,
       fcp.value AS feature_pub_source
FROM feature f
JOIN feature_pub ON feature_pub.feature_id = f.feature_id
JOIN pub ON pub.pub_id = feature_pub.pub_id
JOIN cvterm t ON f.type_id = t.cvterm_id
JOIN feature_pubprop fcp ON fcp.feature_pub_id = feature_pub.feature_pub_id
JOIN cvterm fcpt ON fcp.type_id = fcpt.cvterm_id
WHERE pub.uniquename = ?
  AND t.name = ?
  AND fcpt.name = 'feature_pub_source'
UNION
SELECT f.uniquename AS gene_uniquename,
       f.name AS gene_name,
       fcp.value AS feature_pub_source
FROM feature f
JOIN cvterm ft ON ft.cvterm_id = f.type_id
JOIN feature_cvterm fc ON fc.feature_id = f.feature_id
JOIN pub ON pub.pub_id = fc.pub_id
JOIN feature_cvtermprop fcp ON fcp.feature_cvterm_id = fc.feature_cvterm_id
JOIN cvterm fcpt ON fcpt.cvterm_id = fcp.type_id
WHERE fcpt.name = 'source_file'
  AND pub.uniquename = ?
  AND ft.name = ?
UNION
SELECT DISTINCT gene.uniquename AS gene_uniquename,
                gene.name AS gene_name,
                fcp.value AS feature_pub_source
FROM feature f
JOIN feature_relationship rel ON rel.subject_id = f.feature_id
JOIN cvterm rel_type ON rel_type.cvterm_id = rel.type_id
JOIN feature gene ON gene.feature_id = rel.object_id
JOIN cvterm gene_type ON gene_type.cvterm_id = gene.type_id
JOIN cvterm ft ON ft.cvterm_id = f.type_id
JOIN feature_cvterm fc ON fc.feature_id = f.feature_id
JOIN pub ON pub.pub_id = fc.pub_id
JOIN feature_cvtermprop fcp ON fcp.feature_cvterm_id = fc.feature_cvterm_id
JOIN cvterm fcpt ON fcpt.cvterm_id = fcp.type_id
WHERE fcpt.name = 'source_file'
  AND rel_type.name = 'part_of'
  AND pub.uniquename = ?
  AND gene_type.name = ?
EOQ

  my $sth = $chado_dbh->prepare($query);
  $sth->execute($publication_uniquename, $feature_type,
                $publication_uniquename, $feature_type,
                $publication_uniquename, $feature_type)
    or die "Couldn't execute: " . $sth->errstr;

  my @rows = ();

  while (my ($gene_uniquename, $gene_name, $feature_pub_source) = $sth->fetchrow_array()) {
    push @rows, {
      gene_uniquename => $gene_uniquename,
      gene_name => $gene_name,
      feature_pub_source => $feature_pub_source,
    };
  }

  return @rows;
}
