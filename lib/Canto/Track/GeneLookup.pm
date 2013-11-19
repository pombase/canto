package Canto::Track::GeneLookup;

=head1 NAME

Canto::Track::GeneLookup - A GeneLookup that gets it's data from the TrackDB

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

with 'Canto::Role::Configurable';
with 'Canto::Track::TrackAdaptor';

has 'feature_class' => (is => 'ro', default => 'Gene');
has 'uniquename_column' => (is => 'ro', default => 'primary_identifier');
has 'name_column' => (is => 'ro', default => 'primary_name');
has 'organism_id_column' => (is => 'ro', default => 'organism');

sub gene_product
{
  my $self = shift;
  my $gene = shift;

  return $gene->product();
}

sub _build_synonym_constraint
{
  return map {
    {
      'lower(identifier)' => $_
    },
  } @_;
}

sub lookup_by_synonym_rs
{
  my $self = shift;
  my $search_terms_ref = shift;

  my @lc_search_terms = map { lc } @{$search_terms_ref};

  return $self->schema()->resultset('Genesynonym')
    ->search([_build_synonym_constraint(@lc_search_terms)])
    ->search_related('gene', {}, { prefetch => 'organism' });
}


with 'Canto::Role::ChadoLikeGeneLookup';
with 'Canto::Role::GeneLookupCache';
