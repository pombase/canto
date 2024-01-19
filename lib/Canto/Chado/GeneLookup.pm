package Canto::Chado::GeneLookup;

=head1 NAME

Canto::Track::GeneLookup - A GeneLookup that gets data from a ChadoDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::GeneLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

use feature "state";

with 'Canto::Role::Configurable';
with 'Canto::Chado::ChadoLookup';

has 'feature_class' => (is => 'ro', default => 'Feature');
has 'uniquename_column' => (is => 'ro', default => 'uniquename');
has 'name_column' => (is => 'ro', default => 'name');
has 'organism_id_column' => (is => 'ro', default => 'organism_id');

sub gene_product
{
  my $self = shift;
  my $gene = shift;

  state $cache = {};

  if (!exists $cache->{$gene->feature_id()}) {
    my $schema = $gene->result_source()->schema();

    state $product_cv =
      $schema->resultset('Cv')
        ->search({ name => 'PomBase gene products' })->first();

    # this is a temporary fix as we shouldn't be hard coding the products
    # CV name
    if (defined $product_cv) {
      my $gene_uniquename = $gene->uniquename();
      my $transcript_rs = $schema->resultset('Feature')
        ->search({ uniquename => { -like => "$gene_uniquename.%" }});
      my $rs = $transcript_rs ->search_related('feature_cvterms')
        ->search_related('cvterm', { cv_id => $product_cv->cv_id() });
      my $term = $rs->first();

      if (defined $term) {
        $cache->{$gene->feature_id()} = $term->name();
      } else {
        $cache->{$gene->feature_id()} = undef;
      }
    } else {
      $cache->{$gene->feature_id()} = undef;
    }
  }

  return $cache->{$gene->feature_id()};
}

sub _build_synonym_constraint
{
  return map {
    {
      'lower(me.name)' => $_
    },
  } @_;
}

sub gene_search_options
{
  my $self = shift;
  my %args = @_;
  my $feature_alias = $args{feature_alias};

  return (where => \"$feature_alias.type_id in (select cvterm_id from cvterm where name = 'gene' or name = 'pseudogene')");
}

sub lookup_by_synonym_rs
{
  my $self = shift;
  my $search_terms_ref = shift;

  my @lc_search_terms = map { lc } @{$search_terms_ref};

  my @synonym_constraint;

  if ($self->config()->{chado}->{ignore_case_in_gene_query}) {
    @synonym_constraint = _build_synonym_constraint(@lc_search_terms);
  } else {
    @synonym_constraint = map { { 'me.name' => $_ } } @{$search_terms_ref};
  }

  return $self->schema()->resultset('Synonym')
    ->search([@synonym_constraint])
    ->search_related('feature_synonyms')
    ->search_related('feature', {}, { prefetch => 'organism' });
}

sub get_organism_resultset
{
  my $self = shift;
  my $scientific_name = shift;

  my ($genus, $species) = split / /, $scientific_name;

  return $self->schema()->resultset('Organism')
    ->search({ genus => $genus,
               species => $species });
}

sub synonyms_of_gene_rs
{
  my $self = shift;
  my $gene = shift;

  return $gene->synonyms()->search({}, { columns => [ 'name' ], distinct => 1 });
}

with 'Canto::Role::TaxonIDLookup';
with 'Canto::Role::ChadoLikeGeneLookup';
with 'Canto::Role::GeneLookupCache';
