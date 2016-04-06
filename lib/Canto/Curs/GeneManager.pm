package Canto::Curs::GeneManager;

=head1 NAME

Canto::Curs::GeneManager - Curs Gene CRUD functions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::GeneManager

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

has curs_schema => (is => 'rw', isa => 'Canto::CursDB', required => 1);

with 'Canto::Curs::Role::GeneResultSet';
with 'Canto::Role::Configurable';

# return a list of only those genes which aren't already in the database
sub _filter_existing_genes
{
  my $self = shift;
  my @genes = @_;

  my $schema = $self->curs_schema();

  my @gene_primary_identifiers = map { $_->{primary_identifier} } @genes;

  my $gene_rs = $self->get_ordered_gene_rs($schema);

  my $rs = $gene_rs->search({
    primary_identifier => {
      -in => [@gene_primary_identifiers],
    }
  });

  my %found_genes = ();
  while (defined (my $gene = $rs->next())) {
    $found_genes{$gene->primary_identifier()} = 1;
  }

  return grep { !exists $found_genes{ $_->{primary_identifier} } } @genes;
}

=head2 create_genes_from_lookup

 Usage   : my %results = $self->create_genes_from_lookup($lookup_result);
 Function: Create genes in the CursDB from the result of calling lookup().
           Only creates those genes that aren't there already.
 Args    : $lookup_result - the result of a sucessful call to
           GeneLookup::lookup()
 Return  : A hash of the new genes, the keys are the primary_identifiers and
           values are the the Gene objects

=cut

sub create_genes_from_lookup
{
  my $self = shift;
  my $result = shift;

  my $schema = $self->curs_schema();

  my %ret = ();

  my $_create_curs_genes = sub
      {
        my @genes = @{$result->{found}};

        @genes = $self->_filter_existing_genes(@genes);

        for my $gene (@genes) {
          my $org_full_name = $gene->{organism_full_name};
          my $org_taxonid = $gene->{organism_taxonid};
          my $curs_org =
            Canto::CursDB::Organism::get_organism($schema, $org_full_name,
                                                   $org_taxonid);

          my $primary_identifier = $gene->{primary_identifier};

          my $new_gene = $schema->create_with_type('Gene', {
            primary_identifier => $primary_identifier,
            organism => $curs_org
          });

          $ret{$primary_identifier} = $new_gene
        }
      };

  $schema->txn_do($_create_curs_genes);

  return %ret;
}

=head2 find_and_create_genes

 Usage   : my @results =
             $gene_manager->find_and_create_genes(['cdc11', 'SPBC14F5.07']);
 Function: Given some search terms, search for the terms with a GeneLookup.
           If all terms are found, create a gene in the CursDB for each search
           term.  If any search terms aren't found, don't create any genes just
           return the results of the lookup
 Args    : $search_terms - an array ref of gene name or identifiers to search
                           for
 Return  : If all terms are found return a hash of the created gene, with
           their primary_identifier as the hash key
           If a term isn't found, return a list with the lookup() result and
           two hashes:
             %identifiers_matching_more_than_once
             %genes_matched_more_than_once

=cut

sub find_and_create_genes
{
  my ($self, $search_terms_ref, $create_when_missing) = @_;

  my $schema = $self->curs_schema();
  my $config = $self->config();

  my @search_terms = @$search_terms_ref;
  my $adaptor = Canto::Track::get_adaptor($config, 'gene');

  my $result;

  if (exists $config->{instance_organism}) {
    $result = $adaptor->lookup(
      {
        search_organism => {
          genus => $config->{instance_organism}->{genus},
          species => $config->{instance_organism}->{species},
        }
      },
      [@search_terms]);
  } else {
    $result = $adaptor->lookup([@search_terms]);
  }


  my %identifiers_matching_more_than_once = ();
  my %genes_matched_more_than_once = ();

  map {
    my $match = $_;
    my $primary_identifier = $match->{primary_identifier};
    map {
      my $identifier = $_;
      $identifiers_matching_more_than_once{$identifier}->{$primary_identifier} = 1;
      $genes_matched_more_than_once{$primary_identifier}->{$identifier} = 1;
    } ($match->{match_types}->{primary_identifier} // (),
       $match->{match_types}->{primary_name} // ());
  } @{$result->{found}};

  my @matches_to_remove = ();

  map {
    my $match = $_;
    my $primary_identifier = $match->{primary_identifier};
    map {
      my $identifier = $_;
      if (exists $genes_matched_more_than_once{$identifier}) {
        # synonym is the primary_identifier of some other match
        push @matches_to_remove, $match;
      } else {
        $identifiers_matching_more_than_once{$identifier}->{$primary_identifier} = 1;
        $genes_matched_more_than_once{$primary_identifier}->{$identifier} = 1;
      }
    } @{$match->{match_types}->{synonym} // []},
  } @{$result->{found}};

  @{$result->{found}} =
    grep {
      my $match = $_;
      !grep { $match == $_ } @matches_to_remove;
    } @{$result->{found}};

  sub _remove_single_matches {
    my $hash = shift;
    map {
      my $identifier = $_;

      if (keys %{$hash->{$identifier}} == 1) {
        delete $hash->{$identifier};
      } else {
        $hash->{$identifier} = [sort keys %{$hash->{$identifier}}];
      }
    } keys %$hash;
  }

  _remove_single_matches(\%identifiers_matching_more_than_once);
  _remove_single_matches(\%genes_matched_more_than_once);

  if (@{$result->{missing}} || keys %identifiers_matching_more_than_once > 0 ||
      keys %genes_matched_more_than_once > 0) {
    if ($create_when_missing) {
      $self->_create_genes($schema, $result);
    }

    return ($result, \%identifiers_matching_more_than_once, \%genes_matched_more_than_once);
  } else {
    return ({ $self->create_genes_from_lookup($result) });
  }
}

1;
