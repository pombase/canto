package PomCur::Chado::GeneLookup;

=head1 NAME

PomCur::Track::GeneLookup - A GeneLookup that gets it's data from a ChadoDB

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

use feature "state";

with 'PomCur::Role::Configurable';
with 'PomCur::Chado::ChadoLookup';

has 'feature_class' => (is => 'ro', default => 'Feature');
has 'uniquename_column' => (is => 'ro', default => 'uniquename');
has 'name_column' => (is => 'ro', default => 'name');

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

sub lookup_by_synonym_rs
{
  my $self = shift;
  my $search_terms_ref = shift;

  my @lc_search_terms = map { lc } @{$search_terms_ref};

  return $self->schema()->resultset('Synonym')
    ->search([_build_synonym_constraint(@lc_search_terms)])
    ->search_related('feature_synonyms')
    ->search_related('feature', {}, { prefetch => 'organism' });
}

with 'PomCur::Role::ChadoLikeGeneLookup';
with 'PomCur::Role::GeneLookupCache';
