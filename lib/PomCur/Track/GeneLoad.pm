package PomCur::Track::GeneLoad;

=head1 NAME

PomCur::Track::GeneLoad - Code for loading gene information into a TrackDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::GeneLoad

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;

use PomCur::Track::LoadUtil;

use Text::CSV;

has 'schema' => (
  is => 'ro',
  isa => 'PomCur::TrackDB'
);

has 'load_util' => (
  is => 'ro',
  lazy => 1,
  builder => '_build_load_util'
);

sub _build_load_util
{
  my $self = shift;

  return PomCur::Track::LoadUtil->new(schema => $self->schema());
}

sub _process_gene_row
{
  my $self = shift;

  my $schema = $self->schema();

  my $columns_ref = shift;
  my ($primary_identifier, $name, $synonyms, $product) = @{$columns_ref};

  my $pombe = $self->load_util()->get_organism('Schizosaccharomyces', 'pombe');

  $schema->resultset('Gene')->find_or_create(
    {
      primary_identifier => $primary_identifier,
      product => $product,
      primary_name => $name,
      organism => $pombe
    });
}

=head2 load

 Usage   : my $gene_load = PomCur::Track::GeneLoad->new(schema => $schema);
           $gene_load->load($file_name);
 Function: Load a file of gene identifiers, name and products into the Track
           database
 Args    : $file_name - a comma separated file of genes, one per line:
                           <identifier>,<gene_product>,<name>
                        first line should be a header line:
                           "identifier,product,gene"
 Returns : Nothing

=cut
sub load
{
  my $self = shift;
  my $file_name = shift;

  my $schema = $self->schema();

  my $csv = Text::CSV->new({ binary => 1, sep_char => "\t",
                             blank_is_undef => 1 });
  open my $fh, '<', $file_name or die;

  while (my $columns_ref = $csv->getline($fh)) {
    $self->_process_gene_row($columns_ref);
  }
}

1;
