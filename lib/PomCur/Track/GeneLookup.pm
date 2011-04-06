package PomCur::Track::GeneLookup;

=head1 NAME

PomCur::Track::GeneLookup - A GeneLookup that gets it's data from the TrackDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::GeneLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

with 'PomCur::Role::Configurable';
with 'PomCur::Track::TrackLookup';

sub _build_constraint
{
  return map {
    {
      'lower(primary_identifier)' => $_
    },
    {
      'lower(primary_name)' => $_
    }
  } @_;
}

=head2 lookup

 Usage   : my $gene_lookup = PomCur::Track::get_adaptor($config, 'gene');
           my $results = $gene_lookup->lookup([qw(cdc11 SPCTRNASER.13 test)]);
 Function: Search for genes by name or identifier
 Args    : $search_terms_ref - an array reference containing the terms to search
                               for
 Returns : All genes that match any of the search terms exactly.  The result
           should look like this hashref:
             { found => { "cdc11" => [
                            {
                              primary_name => 'cdc11',
                              primary_identifier => 'SPCTRNASER.13'
                              product => 'SIN component scaffold protein, ...',
                              synonyms => ['foo', 'bar'],
                              organism_full_name => 'Schizosaccharomyces pombe',
                              organism_taxonid => 4896,
                              match_type => 'primary_name',
                            },
                            {
                              primary_name => 'fred1',
                              primary_identifier => 'SPCT...'
                              product => 'SIN component scaffold protein, ...',
                              synonyms => ['foo', 'bar', 'cdc11'],
                              organism_full_name => 'Schizosaccharomyces pombe',
                              organism_taxonid => 4896
                              match_type => 'synonym',
                            },
                          ],
                         "SPCTRNASER.13" => [ ...],
                        },
                        missing => ["test"] }

=cut
sub lookup
{
  my $self = shift;
  my $search_terms_ref = shift;

  my @orig_search_terms = @{$search_terms_ref};
  my @search_terms = map { lc } @{$search_terms_ref};

  my $gene_rs = $self->schema()->resultset('Gene');
  my $rs = $gene_rs->search(
    [_build_constraint(@search_terms)]);

  my @found_genes = ();

  my %gene_ids = ();

  while (defined (my $found_gene = $rs->next())) {
    my $gene_identifier = $found_gene->primary_identifier();
    if (defined $gene_identifier) {
      $gene_ids{lc $gene_identifier} = 1;
    }
    my $gene_name = $found_gene->primary_name();
    if (defined $gene_name) {
      $gene_ids{lc $gene_name} = 1;
    }

    my @synonym_identifiers =
      map { $_->identifier() } $found_gene->genesynonyms();

    push @found_genes, {
      primary_identifier => $found_gene->primary_identifier(),
      primary_name => $found_gene->primary_name(),
      product => $found_gene->product(),
      synonyms => [@synonym_identifiers],
      organism_full_name => $found_gene->organism()->full_name(),
      organism_taxonid => $found_gene->organism()->taxonid(),
    }
  }

  my @missing_genes = grep {
    !exists $gene_ids{lc $_}
  } @orig_search_terms;

  return { found => \@found_genes,
           missing => \@missing_genes };
}

1;
