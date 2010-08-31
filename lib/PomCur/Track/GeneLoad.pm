package PomCur::Track::GeneLoad;

=head1 NAME

PomCur::Track::GeneLoad - Code for loading gene information

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
  my ($primary_name, $product, $name) = @{$columns_ref};

  my $pombe = $self->load_util()->get_organism('Schizosaccharomyces', 'pombe');

  $schema->create_with_type('Gene',
                            {
                              primary_identifier => $primary_name,
                              product => $product,
                              primary_name => $name,
                              organism => $pombe
                            });
}


sub load
{
  my $self = shift;
  my $file_name = shift;

  my $schema = $self->schema();

  my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);

  my $csv = Text::CSV->new({binary => 1});
  open my $fh, '<', $file_name or die;
  $csv->column_names ($csv->getline($fh));

  while (my $columns_ref = $csv->getline($fh)) {
    $self->_process_gene_row($columns_ref);
  }
}

1;
