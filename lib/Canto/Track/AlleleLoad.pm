package Canto::Track::AlleleLoad;

=head1 NAME

Canto::Track::AlleleLoad - Code for loading allele information into
                            the TrackDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::AlleleLoad

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

use Text::CSV;

has 'organism' => (
  is => 'ro',
  isa => 'Canto::TrackDB::Organism',
  required => 1,
);

has 'schema' => (
  is => 'ro',
  isa => 'Canto::TrackDB',
  required => 1,
);

sub _process_allele_row
{
  my $self = shift;
  my $genes = shift;
  my $columns_ref = shift;
  my ($gene_primary_identifier, $allele_primary_name, $allele_details) = @{$columns_ref};

  my $schema = $self->schema();

  my $allele_name;
  my $allele_description;

  if ($allele_details =~ /^(\S+)\((\S+)\)/) {
    ($allele_name, $allele_description) = ($1, $2);
    if ($allele_name eq '' || $allele_name eq 'noname') {
      $allele_name = undef;
    }
    if ($allele_description eq '' || $allele_description eq 'unknown') {
      $allele_description = undef;
    }
  } else {
    die qq|allele data for $allele_primary_name is not in the form | .
      qq|"name(description)" for "$allele_details" instead|;
  }

  my $gene_id = $genes->{$gene_primary_identifier};

  my $new_allele = $schema->resultset('Allele')->create(
    {
      primary_identifier => $allele_primary_name,
      primary_name => $allele_name,
      description => $allele_description,
      gene => $gene_id,
    });
}

=head2 load

 Usage   : my $allele_load = Canto::Track::AlleleLoad->new(schema => $schema);
           $allele_load->load($handle);
 Function: Load a file of allele identifiers, name and products into the Track
           database.  Note that this method doesn't start a transaction.
           Any existing alleles and allele synonyms are removed before
           loading.
 Args    : $handle -  the file handle of a tab separated file of allele
                      information, one allele per line:
                         <gene_identifier>\t<name(description)>
 Returns : Nothing

=cut
sub load
{
  my $self = shift;
  my $handle = shift;

  my $schema = $self->schema();

  my $gene_rs = $schema->resultset('Gene')
    ->search({ organism => $self->organism()->organism_id() });

  my %genes = ();

  while (defined (my $gene = $gene_rs->next())) {
    $genes{$gene->primary_identifier()} = $gene->gene_id();
  }

  my $genealleles_rs = $schema->resultset('Allele')
    ->search({ gene => {
      -in => $gene_rs->get_column('gene_id')->as_query()
    } });
  $genealleles_rs->delete();

  my $csv = Text::CSV->new({ binary => 1, sep_char => "\t",
                             blank_is_undef => 1 });
  while (my $columns_ref = $csv->getline($handle)) {
    $self->_process_allele_row(\%genes, $columns_ref);
  }
}

1;
