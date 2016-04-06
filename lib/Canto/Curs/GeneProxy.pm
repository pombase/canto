package Canto::Curs::GeneProxy;

=head1 NAME

Canto::Curs::GeneProxy - objects that act the same as a CursDB::Gene
     object but actually proxy through a GeneLookup

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::GeneProxy

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;

has cursdb_gene => (is => 'ro', required => 1,
                    handles => {
                      gene_id => 'gene_id',
                      feature_id => 'gene_id',
                      alleles => 'alleles',
                      direct_annotations => 'direct_annotations',
                      indirect_annotations => 'indirect_annotations',
                      all_annotations => 'all_annotations',
                      primary_identifier => 'primary_identifier',
                      delete => 'delete',
                    });
has gene_lookup => (is => 'ro', init_arg => undef, lazy_build => 1);
has primary_name => (is => 'ro', init_arg => undef, lazy_build => 1);
has display_name => (is => 'ro', init_arg => undef, lazy_build => 1);
has product => (is => 'ro', init_arg => undef, lazy_build => 1);
has synonyms_ref => (is => 'ro', init_arg => undef, lazy_build => 1,
                 isa => 'ArrayRef[Str]',
                 traits => ['Array'],
                 handles => { synonyms => 'elements' },
               );
has gene_data => (is => 'ro', init_arg => undef, lazy_build => 1);
has organism => (is => 'ro', init_arg => undef, lazy_build => 1);
has taxonid => (is => 'ro', init_arg => undef, lazy_build => 1);

with 'Canto::Role::Configurable';
with 'Canto::Role::GeneNames';

sub BUILD
{
  my $self = shift;

  if (!defined $self->cursdb_gene()) {
    croak "No cursdb_gene passed to GeneProxy";
  }
}

sub _build_gene_lookup
{
  my $self = shift;

  return Canto::Track::get_adaptor($self->config(), 'gene');
}

sub _build_gene_data
{
  my $self = shift;
  my $primary_identifier = $self->primary_identifier();

  my $gene_lookup = $self->gene_lookup();

  my $res = $gene_lookup->lookup([$primary_identifier]);

  my $found = $res->{found};

  if (!defined $found) {
    croak "internal error: can't find gene for $primary_identifier " .
      "using $gene_lookup";
  }

  my @found_genes = grep {
    $_->{primary_identifier} eq $primary_identifier;
  } @{$found};

  if (@found_genes > 1) {
    croak "internal error: lookup returned more than one gene for " .
      $primary_identifier;
  }

  if (@found_genes == 0) {
    croak "lookup failed for gene: $primary_identifier";
  }

  return $found_genes[0];
}

sub _build_primary_name
{
  my $self = shift;

  return $self->gene_data()->{primary_name};
}

sub _build_display_name
{
  my $self = shift;

  return $self->primary_name() // $self->primary_identifier();
}

sub _build_product
{
  my $self = shift;

  return $self->gene_data()->{product};
}

sub _build_synonyms_ref
{
  my $self = shift;

  return $self->gene_data()->{synonyms};
}

sub _build_taxonid
{
  my $self = shift;

  return $self->gene_data()->{organism_taxonid};
}

sub _build_organism
{
  my $self = shift;

  return $self->cursdb_gene()->organism();
}

1;
