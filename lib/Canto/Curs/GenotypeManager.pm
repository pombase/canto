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
with 'Canto::Role::MetadataAccess';

sub _build_allele_manager
{
  my $self = shift;

  return Canto::Curs::AlleleManager->new(config => $self->config(),
                                         curs_schema => $self->curs_schema());
}

sub _string_or_undef
{
  my $string = shift;

  return $string // '<__UNDEF__>';
}

=head2 find_with_alleles

 Usage   : my $existing = $manager->find_with_alleles(\@alleles);
 Function: Return any existing genotype with exactly the given alleles.
           We should have at most one in the CursDB.
 Return  : the found Genotype or undef if there is no Genotype with those
           alleles

=cut

sub find_with_alleles
{
  my $self = shift;
  my $search_alleles = shift;

  my @sorted_search_allele_ids =
    sort {
      $a <=> $b;
    } map {
      $_->allele_id();
    } @$search_alleles;

  my $joined_search_ids = join " ", @sorted_search_allele_ids;

  my $schema = $self->curs_schema();

  my $genotype_rs = $schema->resultset('Genotype');

  while (defined (my $genotype = $genotype_rs->next())) {
    my @alleles = $genotype->alleles();

    next if scalar(@alleles) != scalar(@$search_alleles);

    my @sorted_allele_ids = sort {
      $a <=> $b;
    } map {
      $_->allele_id();
    } $genotype->alleles();

    if ((join " ", @sorted_allele_ids) eq $joined_search_ids) {
      return $genotype;
    }
  }

  return undef;
}

=head2 make_genotype

 Usage   : $genotype_manager->make_genotype($curs_key, $name, $background, \@allele_objects,
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
  my $background = shift;
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
                                background => $background || undef,
                              });

  if (!defined $identifier) {
    my $genotype_id = $genotype->genotype_id();
    $genotype->identifier("$curs_key-genotype-$genotype_id");
  }

  $genotype->set_alleles($alleles);

  $genotype->update();

  return $genotype;
}


=head2 store_genotype_changes

 Usage   : $genotype_manager->store_genotype_changes($curs_key, $genotype,
                                                     $name, $background, \@allele_objects);
 Function: Store changes to a Genotype object in the CursDB
 Args    : $curs_key - the key for this session
           $genotype_id - the Genotype's ID in the CursDB
           $name - new name for the genotype, note: if undef the name will be
                   set to undef rather than keeping the old version (optional)
           $background - the genotype background (optional)
           \@allele_objects - a list of Allele objects to attach to the new
                              Genotype
 Return  : nothing, dies on error

=cut

sub store_genotype_changes
{
  my $self = shift;
  my $curs_key = shift;
  my $genotype = shift;
  my $name = shift;
  my $background = shift;
  my $alleles = shift;

  my $schema = $self->curs_schema();

  $genotype->name($name);
  $genotype->background($background);
  $genotype->set_alleles($alleles);

  $genotype->update();
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
  my $background = $chado_genotype_details->{background};
  my $identifier = $chado_genotype_details->{identifier};

  return $self->make_genotype($curs_key, $name, $background, \@alleles, $identifier);
}

=head2 find_and_create_genotype

 Usage   : $genotype_manager->find_and_create_genotype($genotype_identifier);
 Function: Find the genotype given by $genotype_identifier in Chado and copy to
           the CursDB
 Args    : $genotype_identifier
 Return  : the new Genotype object from the CursDB

=cut

sub find_and_create_genotype
{
  my $self = shift;

  my $schema = $self->curs_schema();
  my $curs_key = $self->get_metadata($schema, 'curs_key');

  my $genotype_identifier = shift;

  my $lookup = Canto::Track::get_adaptor($self->config(), 'genotype');

  if (!$lookup) {
    die 'NO genotype adaptor configured';

  }

  my $chado_genotype_details = $lookup->lookup(identifier => $genotype_identifier);

  return $self->_store_chado_genotype($curs_key, $chado_genotype_details);
}

=head2 delete_genotype

 Usage   : $utils->delete_genotype($genotype_identifier);
 Function: Remove a genotype from the CursDB if it has no annotations.
           Any alleles not referenced by another Genotype will be removed too.
 Args    : $genotype_id
 Return  : Nothing - dies on error or if the genotype has some annotations

=cut

sub delete_genotype
{
  my $self = shift;
  my $genotype_id = shift;

  my $schema = $self->curs_schema();

  my $genotype = $schema->resultset('Genotype')->find($genotype_id);

  if ($genotype->annotations()->count() > 0) {
    die "has_annotations\n";
  }

  $genotype->delete();
}

1;
