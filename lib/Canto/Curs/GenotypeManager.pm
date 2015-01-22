package Canto::Curs::GenotypeManager;

=head1 NAME

Canto::Curs::GenotypeManager - Curs Genotype CRUD functions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::GenotypeManager

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

use Canto::Curs::AlleleManager;

has curs_schema => (is => 'rw', isa => 'Canto::CursDB', required => 1);
has allele_manager => (is => 'rw', isa => 'Canto::Curs::AlleleManager',
                       lazy_build => 1);

with 'Canto::Role::Configurable';

sub _build_allele_manager
{
  my $self = shift;

  return Canto::Curs::AlleleManager->new(config => $self->config(),
                                         curs_schema => $self->curs_schema());
}

=head2 make_genotype

 Usage   : $genotype_manager->make_genotype($curs_key, $name, \@allele_objects,
                                            $identifier);
 Function: Create a Genotype object in the CursDB
 Args    : $curs_key - the key for this session
           $name - the name for the new object (required)
           \@allele_objects - a list of Allele objects to attach to the new
                              Genotype
           $identifier - the identifier of the new object if the Genotype
                         details are from an external source (Chado) or undef
                         for Genotypes created in this session.  If not defined
                         a new unique identifier will be created based on the
                         $curs_key
 Return  : the new Genotype

=cut

sub make_genotype
{
  my $self = shift;
  my $curs_key = shift;
  my $name = shift;
  my $alleles = shift;
  my $identifier = shift;  # defined if this genotype is from Chado

  my $schema = $self->curs_schema();

  my $new_identifier;

  if (defined $identifier) {
    $new_identifier = $identifier;
  } else {
    $new_identifier = 'canto-genotype-temp-' . int(rand 10000000);
  }

  my $genotype =
    $schema->create_with_type('Genotype',
                              {
                                identifier => $new_identifier,
                                name => $name || undef,
                              });

  if (!defined $identifier) {
    my $genotype_id = $genotype->genotype_id();
    $genotype->identifier("$curs_key-genotype-$genotype_id");
  }

  $genotype->set_alleles($alleles);

  $genotype->update();

  return $genotype;
}


sub _store_chado_genotype
{
  my $self = shift;
  my $curs_key = shift;
  my $chado_genotype_details = shift;

  my $schema = $self->curs_schema();

  my @alleles_data = map {
    {
      primary_identifier => $_,
    };
  } @{$chado_genotype_details->{allele_identifiers}};

  my @alleles = ();

  my $allele_manager = $self->allele_manager();

  for my $allele_data (@alleles_data) {
    my $allele = $allele_manager->allele_from_json($allele_data, $curs_key,
                                                   \@alleles);

    push @alleles, $allele;
  }

  my $name = $chado_genotype_details->{name};
  my $identifier = $chado_genotype_details->{identifier};

  return $self->make_genotype($curs_key, $name, \@alleles, $identifier);
}

sub find_and_create_genotype
{
  my $self = shift;
  my $curs_key = shift;
  my $genotype_identifier = shift;

  my $lookup = Canto::Track::get_adaptor($self->config(), 'genotype');

  if (!$lookup) {
    die 'NO genotype adaptor configured';

  }

  my $chado_genotype_details = $lookup->lookup(identifier => $genotype_identifier);

  return $self->_store_chado_genotype($curs_key, $chado_genotype_details);
}

1;
