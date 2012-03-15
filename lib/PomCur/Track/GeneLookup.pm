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
with 'PomCur::Track::TrackAdaptor';

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

sub _build_synonym_constraint
{
  return map {
    {
      'lower(identifier)' => $_
    },
  } @_;
}

sub _read_genes
{
  my $rs = shift;
  my $search_terms_ref = shift;
  my $existing_genes = shift;

  my @found_genes = ();
  my %gene_ids = %$existing_genes;
  my %terms_found = ();

  while (defined (my $found_gene = $rs->next())) {
    next if exists $gene_ids{$found_gene->gene_id()};

    $gene_ids{$found_gene->gene_id()} = 1;

    my %match_types;

    my $primary_identifier = $found_gene->primary_identifier();

    if (exists $search_terms_ref->{lc $primary_identifier}) {
      $match_types{primary_identifier} = $primary_identifier;
      $terms_found{lc $primary_identifier} = 1;
    }

    my $primary_name = $found_gene->primary_name();
    if (defined $primary_name && exists $search_terms_ref->{lc $primary_name}) {
      $match_types{primary_name} = $primary_name;
      $terms_found{lc $primary_name} = 1;
    }

    my @synonym_identifiers = ();

    for my $synonym ($found_gene->genesynonyms()) {
      my $synonym_identifier = $synonym->identifier();
      push @synonym_identifiers, $synonym_identifier;

      if (exists $search_terms_ref->{lc $synonym_identifier}) {
        push @{$match_types{synonym}}, $synonym_identifier;
        $terms_found{lc $synonym_identifier} = 1;
      }
    }

    push @found_genes, {
      primary_identifier => $found_gene->primary_identifier(),
      primary_name => $found_gene->primary_name(),
      product => $found_gene->product(),
      synonyms => [@synonym_identifiers],
      organism_full_name => $found_gene->organism()->full_name(),
      organism_taxonid => $found_gene->organism()->taxonid(),
      match_types => \%match_types,
    }
  }

  return (\@found_genes, \%gene_ids, \%terms_found);
}

=head2 lookup

 Usage   : my $gene_lookup = PomCur::Track::get_adaptor($config, 'gene');
           my $results =
             $gene_lookup->lookup([qw(cdc11 SPCTRNASER.13 test foo)]);
 Function: Search for genes by name or identifier
 Args    : $search_terms_ref - an array reference containing the terms to search
                               for
 Returns : All genes that match any of the search terms exactly.  The result
           should look like this hashref:
            { found => [{
                         primary_name => 'cdc11',
                         primary_identifier => 'SPCTRNASER.13'
                         product => 'SIN component scaffold protein, ...',
                         synonyms => ['foo', 'bar'],
                         organism_full_name => 'Schizosaccharomyces pombe',
                         organism_taxonid => 4896,
                         match_types => { primary_name => 'cdc11',
                                          primary_identifier => 'SPCTRNASER.13',
                                          synonym => [ 'foo' ],
                                        },
                        }, ... ],
              missing => ['test'] }

=cut

sub lookup
{
  my $self = shift;
  my $search_terms_ref = shift;

  my @orig_search_terms = @{$search_terms_ref};

  my @lc_search_terms = map { lc } @{$search_terms_ref};

  my %lc_search_terms = ();
  @lc_search_terms{@lc_search_terms} = @lc_search_terms;

  my $gene_rs = $self->schema()->resultset('Gene');
  my $rs = $gene_rs->search(
    [_build_constraint(@lc_search_terms)]);


  my ($found_genes_ref, $gene_ids_ref, $terms_found_ref) =
    _read_genes($rs, \%lc_search_terms, {});

  my @found_genes = @$found_genes_ref;
  my %gene_ids = %$gene_ids_ref;
  my %terms_found = %$terms_found_ref;

  $rs = $self->schema()->resultset('Genesynonym')
    ->search([_build_synonym_constraint(@lc_search_terms)])
    ->search_related('gene');

  my ($new_found_genes_ref, $dummy, $new_terms_found_ref) =
    _read_genes($rs, \%lc_search_terms, \%gene_ids);

  @terms_found{keys %$new_terms_found_ref} = values %$new_terms_found_ref;

  push @found_genes, @$new_found_genes_ref;

  my @missing_genes = grep {
    !exists $terms_found{lc $_}
  } @orig_search_terms;

  return { found => \@found_genes,
           missing => \@missing_genes };
}

1;
