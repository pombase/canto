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

use Carp;
use Moose;

use Text::CSV;

has 'organism' => (
  is => 'ro',
  isa => 'PomCur::TrackDB::Organism',
  required => 1,
);

has 'schema' => (
  is => 'ro',
  isa => 'PomCur::TrackDB',
  required => 1,
);

sub _process_gene_row
{
  my $self = shift;

  my $schema = $self->schema();

  my $columns_ref = shift;
  my ($primary_identifier, $name, $synonyms, $product) = @{$columns_ref};

  my @synonym_hashes = ();

  if (defined $synonyms) {
    @synonym_hashes = map {
      s/^\s+//; s/\s+$//;
      {
        identifier => $_,
      }
    } split /,/, $synonyms;
  }

  my $organism = $self->organism();

  $schema->resultset('Gene')->create(
    {
      primary_identifier => $primary_identifier,
      product => $product,
      primary_name => $name,
      organism => $organism,
      genesynonyms => [ @synonym_hashes ],
    });
}

=head2 load

 Usage   : my $gene_load = PomCur::Track::GeneLoad->new(schema => $schema);
           $gene_load->load($handle);
 Function: Load a file of gene identifiers, name and products into the Track
           database.  Note that this method doesn't start a transaction.
           Any existing genes and gene synonyms are removed before
           loading.
 Args    : $handle -  the file handle of a tab separated file of gene
                      information, one gene per line:
                         <identifier>\t<name>\t<synonyms>\t<gene_products>
                      the synonyms field should be a comma separated
                      list of the synonyms
 Returns : Nothing

=cut
sub load
{
  my $self = shift;
  my $handle = shift;

  my $schema = $self->schema();

  my $gene_rs = $schema->resultset('Gene')
    ->search({ organism => $self->organism()->organism_id() });

  my $genesynonyms_rs = $schema->resultset('Genesynonym')
    ->search({ gene => {
      -in => $gene_rs->get_column('gene_id')->as_query()
    } });
  $genesynonyms_rs->delete();

  $gene_rs->delete();

  my $csv = Text::CSV->new({ binary => 1, sep_char => "\t",
                             blank_is_undef => 1 });
  while (my $columns_ref = $csv->getline($handle)) {
    $self->_process_gene_row($columns_ref);
  }
}

1;
