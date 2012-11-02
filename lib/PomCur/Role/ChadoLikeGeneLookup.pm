package PomCur::Role::ChadoLikeGeneLookup;

=head1 NAME

PomCur::Role::ChadoLikeGeneLookup - Code for looking up genes in schemas
                                    similar to Chado

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Role::ChadoLikeGeneLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose::Role;

requires 'feature_class';
requires 'lookup_by_synonym_rs';

sub _build_constraint
{
  my $self = shift;

  my $uniquename_column = $self->uniquename_column();
  my $name_column = $self->name_column();

  return map {
    {
      "lower($uniquename_column)" => $_
    },
    {
      "lower($name_column)" => $_
    }
  } @_;
}

sub _read_genes
{
  my $self = shift;
  my $rs = shift;
  my $search_terms_ref = shift;
  my $existing_genes = shift;

  my @found_genes = ();
  my %gene_ids = %$existing_genes;
  my %terms_found = ();

  while (defined (my $found_gene = $rs->next())) {
    next if exists $gene_ids{$found_gene->feature_id()};

    $gene_ids{$found_gene->feature_id()} = 1;

    my %match_types;

    my $uniquename_column = $self->uniquename_column();
    my $primary_identifier = $found_gene->$uniquename_column();

    if (exists $search_terms_ref->{lc $primary_identifier}) {
      $match_types{primary_identifier} = $primary_identifier;
      $terms_found{lc $primary_identifier} = 1;
    }

    my $name_column = $self->name_column();
    my $primary_name = $found_gene->$name_column();
    if (defined $primary_name && exists $search_terms_ref->{lc $primary_name}) {
      $match_types{primary_name} = $primary_name;
      $terms_found{lc $primary_name} = 1;
    }

    my @synonym_identifiers = ();

    for my $synonym ($found_gene->synonyms()) {
      my $synonym_identifier = $synonym->name();
      push @synonym_identifiers, $synonym_identifier;

      if (exists $search_terms_ref->{lc $synonym_identifier}) {
        push @{$match_types{synonym}}, $synonym_identifier;
        $terms_found{lc $synonym_identifier} = 1;
      }
    }

    push @found_genes, {
      primary_identifier => $found_gene->$uniquename_column(),
      primary_name => $found_gene->$name_column(),
      product => $self->gene_product($found_gene),
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
       or:
           my $results =
             $gene_lookup->lookup({ search_organism => {
                                      genus => 'Schizosaccharomyces',
                                      species => 'pombe',
                                    }
                                  },
                                  [qw(cdc11 SPCTRNASER.13 test foo)]);
 Function: Search for genes by name or identifier
 Args    : $options - a hash ref of options,optional
              valid options: search_organism - restrict the search to the
                                               given organism
           $search_terms_ref - an array reference containing the terms to search
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

  my $options = {};
  if (@_ == 2) {
    $options = shift;
  }
  my $search_terms_ref = shift;

  my @orig_search_terms = @{$search_terms_ref};
  my @lc_search_terms = map { lc } @{$search_terms_ref};

  my $org_constraint = undef;

  if (exists $options->{search_organism}) {
    my $search_species = $options->{search_organism}->{species};
    my $search_genus = $options->{search_organism}->{genus};

    my $org_rs = $self->schema()->resultset('Organism')
      ->search({ species => $search_species,
                 genus => $search_genus });

    $org_constraint = {
      -in => $org_rs->get_column('organism_id')->as_query(),
    };
  }

  my %lc_search_terms = ();
  @lc_search_terms{@lc_search_terms} = @lc_search_terms;

  my $gene_rs = $self->schema()->resultset($self->feature_class());
  my $rs = $gene_rs->search([$self->_build_constraint(@lc_search_terms)]);
  if (defined $org_constraint) {
    $rs = $rs->search({ 'me.' . $self->organism_id_column() => $org_constraint });
  }

  my ($found_genes_ref, $gene_ids_ref, $terms_found_ref) =
    $self->_read_genes($rs, \%lc_search_terms, {});

  my @found_genes = @$found_genes_ref;
  my %gene_ids = %$gene_ids_ref;
  my %terms_found = %$terms_found_ref;

  $rs = $self->lookup_by_synonym_rs($search_terms_ref);
  if (defined $org_constraint) {
    $rs = $rs->search({ lc $self->feature_class() . '.' . $self->organism_id_column() => $org_constraint });
  }

  my ($new_found_genes_ref, $dummy, $new_terms_found_ref) =
    $self->_read_genes($rs, \%lc_search_terms, \%gene_ids);

  @terms_found{keys %$new_terms_found_ref} = values %$new_terms_found_ref;

  push @found_genes, @$new_found_genes_ref;

  my @missing_genes = grep {
    !exists $terms_found{lc $_}
  } @orig_search_terms;

  return { found => \@found_genes,
           missing => \@missing_genes };
}

1;
