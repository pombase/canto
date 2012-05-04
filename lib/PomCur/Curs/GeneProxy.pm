package PomCur::Curs::GeneProxy;

=head1 NAME

PomCur::Curs::GeneProxy - objects that act the same as a CursDB::Gene
     object but actually proxy through a GeneLookup

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Curs::GeneProxy

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;

has cursdb_gene => (is => 'ro', required => 1,
                    handles => [qw(gene_id
                                   direct_annotations
                                   indirect_annotations
                                   all_annotations
                                   primary_identifier
                                   delete)]);
has gene_lookup => (is => 'ro', init_arg => undef, lazy_build => 1);
has primary_name => (is => 'ro', init_arg => undef, lazy_build => 1);
has product => (is => 'ro', init_arg => undef, lazy_build => 1);
has synonyms_ref => (is => 'ro', init_arg => undef, lazy_build => 1,
                 isa => 'ArrayRef[Str]',
                 traits => ['Array'],
                 handles => { synonyms => 'elements' },
               );
has gene_data => (is => 'ro', init_arg => undef, lazy_build => 1);

with 'PomCur::Role::Configurable';
with 'PomCur::Role::GeneNames';

sub _build_gene_lookup
{
  my $self = shift;

  return PomCur::Track::get_adaptor($self->config(), 'gene');
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

  my @found_genes = @{$found};

  if (@found_genes > 1) {
    croak "internal error: lookup returned more than one gene for " .
      $primary_identifier;
  }

  return $found_genes[0];
}

sub _build_primary_name
{
  my $self = shift;

  return $self->gene_data()->{primary_name};
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

sub organism
{
  my $self = shift;

  return $self->cursdb_gene()->organism();
}

1;
