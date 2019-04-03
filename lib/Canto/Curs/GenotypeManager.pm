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

use Canto::Track;
use Canto::Curs::AlleleManager;
use Canto::Curs::StrainManager;
use Canto::Curs::OrganismManager;

has curs_schema => (is => 'ro', isa => 'Canto::CursDB', required => 1);
has curs_key => (is => 'rw', lazy_build => 1);
has allele_manager => (is => 'rw', isa => 'Canto::Curs::AlleleManager',
                       lazy_build => 1);
has organism_manager => (is => 'rw', isa => 'Canto::Curs::OrganismManager',
                         lazy_build => 1);

has strain_manager => (is => 'rw', isa => 'Canto::Curs::StrainManager',
                       lazy_build => 1);

with 'Canto::Role::Configurable';
with 'Canto::Role::MetadataAccess';

sub _build_curs_key
{
  my $self = shift;
  my $schema = $self->curs_schema();

  return $self->get_metadata($schema, 'curs_key');
}

sub _build_allele_manager
{
  my $self = shift;

  return Canto::Curs::AlleleManager->new(config => $self->config(),
                                         curs_schema => $self->curs_schema());
}

sub _build_organism_manager
{
  my $self = shift;

  return Canto::Curs::OrganismManager->new(config => $self->config(),
                                           curs_schema => $self->curs_schema());
}

sub _build_strain_manager
{
  my $self = shift;

  return Canto::Curs::StrainManager->new(config => $self->config(),
                                         curs_schema => $self->curs_schema());
}

sub _string_or_undef
{
  my $string = shift;

  return $string // '<__UNDEF__>';
}

=head2 find_genotype

 Usage   : my $existing = $manager->find_genotype($taxon_id, $background,
                                                  $strain_name, \@alleles);
 Function: Return any existing genotype the same background and alleles as
           the argument.
           We should have at most one in the CursDB.
 Args    : - $taxon_id
           - $background - can be undef
           - $strain_name - can be undef
           - \@alleles
 Return  : the found Genotype or undef if there is no Genotype with those
           alleles

=cut

sub find_genotype
{
  my $self = shift;

  my $genotype_taxonid = shift;
  my $new_background = shift;
  my $strain_name = shift;
  my $search_alleles = shift;

  if (defined $new_background) {
    $new_background =~ s/^\s+//;
    $new_background =~ s/\s+$//;

    $new_background = undef if length $new_background == 0;
  }

  my $organism = $self->organism_manager()->add_organism_by_taxonid($genotype_taxonid);

  my $strain_id = undef;

  if ($strain_name) {
    my $strain = $self->strain_manager()->find_strain_by_name($genotype_taxonid, $strain_name);
    $strain_id = $strain->strain_id();
  }


  my @sorted_search_allele_ids =
    sort {
      $a <=> $b;
    } map {
      $_->allele_id();
    } @$search_alleles;

  my $joined_search_ids = join " ", @sorted_search_allele_ids;

  my $schema = $self->curs_schema();

  my $genotype_rs = $schema->resultset('Genotype');

  if ($strain_id) {
    $genotype_rs = $genotype_rs->search({ strain_id => $strain_id });
  }

  while (defined (my $genotype = $genotype_rs->next())) {
    if ($genotype->background() && $new_background &&
        $genotype->background() ne $new_background) {
      next;
    }

    if (!$genotype->background() && $new_background ||
        $genotype->background() && !$new_background) {
      next;
    }

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

sub _remove_unused_alleles
{
  my $self = shift;

  my $alleles_with_no_genotype_rs =
    $self->curs_schema()->resultset('Allele')->search({},
                                         {
                                           where => \"allele_id NOT IN (SELECT allele FROM allele_genotype)",
                                         });

  $alleles_with_no_genotype_rs->delete();
}

=head2 make_genotype

 Usage   : $genotype_manager->make_genotype($name, $background, \@allele_objects,
                                            $genotype_taxonid, $identifier, $strain_name);
 Function: Create a Genotype object in the CursDB
 Args    : $name - the name for the new object
           \@allele_objects - a list of Allele objects to attach to the new
                              Genotype
           $genotype_taxonid - the organism of this genotype
           $identifier - the identifier of the new object if the Genotype
                         details are from an external source (Chado) or undef
                         for Genotypes created in this session.  If not defined
                         a new unique identifier will be created based on the
                         session curs_key
           $strain_name - the name of the strain of this genotype which must
                          already be added to the session (optional)
           $comment - an optional comment field
 Return  : the new Genotype

=cut

sub make_genotype
{
  my $self = shift;

  my $name = shift;
  my $background = shift;
  my $alleles = shift;
  my $genotype_taxonid = shift;
  my $identifier = shift;  # defined if this genotype is from Chado
  my $strain_name = shift;
  my $comment = shift;

  if (!defined $genotype_taxonid) {
    croak "no taxon ID passed to GenotypeManager::make_genotype()\n";
  }

  my $schema = $self->curs_schema();

  my $curs_key = $self->curs_key();

  my $new_identifier;

  if (defined $identifier) {
    $new_identifier = $identifier;
  } else {
    $new_identifier = 'canto-genotype-temp-' . int(rand 10000000);
  }

  my $organism = $self->organism_manager()->add_organism_by_taxonid($genotype_taxonid);

  if (!defined $organism) {
    die "can't find organism with taxon ID: $genotype_taxonid";
  }

  my $genotype =
    $schema->create_with_type('Genotype',
                              {
                                identifier => $new_identifier,
                                name => $name || undef,
                                background => $background || undef,
                                comment => $comment || undef,
                                organism_id => $organism->organism_id(),
                              });

  if (!defined $identifier) {
    my $genotype_id = $genotype->genotype_id();
    $genotype->identifier("$curs_key-genotype-$genotype_id");
  }

  $genotype->set_alleles($alleles);

  if ($strain_name) {
    my $strain = $self->strain_manager()->find_strain_by_name($genotype_taxonid, $strain_name);
    $genotype->strain($strain);
  }

  $genotype->update();

  return $genotype;
}

=head2 get_wildtype_genotype

 Usage   : $genotype_manager->get_wildtype_genotype($taxonid, $strain_name);
 Function: Create a wild-type Genotype object in the CursDB - the genotype will have
           no alleles
 Args    : $genotype_taxonid - the organism of this genotype
 Return  : the new Genotype

=cut

sub get_wildtype_genotype
{
  my $self = shift;
  my $genotype_taxonid = shift;
  my $strain_name = shift;

  if (!defined $genotype_taxonid) {
    croak "no taxon ID passed to GenotypeManager::make_genotype()\n";
  }

  my $schema = $self->curs_schema();

  my $rs = $schema->resultset('Genotype')
    ->search({ 'organism.taxonid' => $genotype_taxonid }, { join => 'organism' });

  my $strain = undef;

  if ($strain_name) {
    $strain = $self->strain_manager()->find_strain_by_name($genotype_taxonid, $strain_name);
  }

  while (defined (my $genotype = $rs->next())) {
    if ($genotype->alleles()->count() == 0 &&
          (!$strain && !$genotype->strain_id() ||
           $strain && $genotype->strain_id() && $genotype->strain_id() == $strain->strain_id())) {
      return $genotype;
    }
  }

  my $organism_lookup = Canto::Track::get_adaptor($self->config(), 'organism');

  my $host_details =
    $organism_lookup->lookup_by_taxonid($genotype_taxonid);

  my $identifier = $host_details->{scientific_name} =~ s/ /-/gr . '-wild-type-genotype';

  if ($strain_name) {
    $identifier .= $strain_name =~ s/ /-/gr;
  }

  return $self->make_genotype(undef, undef, [], $genotype_taxonid, $identifier, $strain_name);
}

sub _get_metagenotype_identifier
{
  my $self = shift;

  my $curs_key = $self->curs_key();

  my $rs = $self->curs_schema()->resultset('Metagenotype');

  my $id = 0;

  while(defined (my $metagenotype = $rs->next())) {
    my $identifier = $metagenotype->identifier();

    if ($identifier =~ /^$curs_key-metagenotype-(\d+)/) {
      if ($1 > $id) {
        $id = $1;
      }
    }
  }

  return "$curs_key-metagenotype-" . ($id + 1);
}


=head2 make_metagenotype

 Usage   : my $metagenotype =
             $genotype_manager->make_metagenotype(host_genotype => $host_genotype,
                                                  pathogen_genotype => $pathogen_genotype);
 Function: Create a metagenotype from it's parts

=cut

sub make_metagenotype
{
  my $self = shift;

  my %args = @_;

  my $organism_lookup = Canto::Track::get_adaptor($self->config(), 'organism');

  my $host_genotype = $args{host_genotype};
  my $host_details =
    $organism_lookup->lookup_by_taxonid($host_genotype->organism()->taxonid());

  if ($host_details->{pathogen_or_host} ne 'host') {
    die "organism of genotype passed with the 'host' arg isn't a host: " .
      $host_details->{pathogen_or_host};
  }

  my $pathogen_genotype = $args{pathogen_genotype};
  my $pathogen_details =
    $organism_lookup->lookup_by_taxonid($pathogen_genotype->organism()->taxonid());

  if ($pathogen_details->{pathogen_or_host} ne 'pathogen') {
    die "organism of genotype passed with the 'pathogen' arg isn't a pathogen: " .
      $pathogen_details->{pathogen_or_host};
  }

  my $schema = $self->curs_schema();

  my $metagenotype_identifier = $self->_get_metagenotype_identifier();

  my $metagenotype =
    $schema->create_with_type('Metagenotype',
                              {
                                identifier => $metagenotype_identifier,
                                pathogen_genotype_id => $pathogen_genotype->genotype_id(),
                                host_genotype_id => $host_genotype->genotype_id(),
                              });
  return $metagenotype;
}


=head2 store_genotype_changes

 Usage   : $genotype_manager->store_genotype_changes($genotype,
                                                     $name, $background, \@allele_objects,
                                                     $strain_name);
 Function: Store changes to a Genotype object in the CursDB
 Args    : $genotype - the Genotype object
           $name - new name for the genotype, note: if undef the name will be
                   set to undef rather than keeping the old version (optional)
           $background - the genotype background (optional)
           $genotype_taxonid - the organism of this genotype
           \@allele_objects - a list of Allele objects to attach to the new
                              Genotype
           $strain_name - the name of the strain of this genotype which must
                          already be added to the session (optional)
 Return  : nothing, dies on error

=cut

sub store_genotype_changes
{
  my $self = shift;
  my $genotype = shift;
  my $name = shift;
  my $background = shift;
  my $genotype_taxonid = shift;
  my $alleles = shift;
  my $strain_name = shift;
  my $comment = shift;

  my $schema = $self->curs_schema();

  # store undef not ""
  $name = undef if defined $name && $name =~ /^\s*$/;

  $genotype->name($name);
  $genotype->background($background);
  $genotype->comment($comment);

  my $organism = $self->organism_manager()->add_organism_by_taxonid($genotype_taxonid);
  $genotype->organism_id($organism->organism_id());
  $genotype->set_alleles($alleles);

  if ($strain_name) {
    my $strain = $self->strain_manager()->find_strain_by_name($genotype_taxonid, $strain_name);
    $genotype->strain($strain);
  }

  $self->_remove_unused_alleles();

  $genotype->update();
}


sub _store_chado_genotype
{
  my $self = shift;
  my $chado_genotype_details = shift;

  my $curs_key = $self->curs_key();

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

  return $self->make_genotype($name, $background, \@alleles,
                              $alleles[0]->gene()->organism()->taxonid(),
                              $identifier);
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

  my $genotype_identifier = shift;

  my $lookup = Canto::Track::get_adaptor($self->config(), 'genotype');

  if (!$lookup) {
    die 'NO genotype adaptor configured';
  }

  my $chado_genotype_details = $lookup->lookup(identifier => $genotype_identifier);

  return $self->_store_chado_genotype($chado_genotype_details);
}

=head2 find_metagenotype

 Usage   : $genotype_manager->find_metagenotype(pathogen_genotype => $pathogen_genotype,
                                                host_genotype => $host_genotype);
 Function: Find the metagenotype composed of the given pathogen and host genotypes
 Return  : the Metagenotype object from the CursDB or undef

=cut

sub find_metagenotype
{
  my $self = shift;

  my %args = @_;

  my $schema = $self->curs_schema();

  my %search_args = (
    pathogen_genotype_id => $args{pathogen_genotype}->genotype_id(),
    host_genotype_id => $args{host_genotype}->genotype_id(),
  );

  return $schema->resultset('Metagenotype')->find(\%search_args);
}

=head2 delete_genotype

 Usage   : $utils->delete_genotype($genotype_id);
 Function: Remove a genotype from the CursDB if it has no annotations.
           Any alleles not referenced by another Genotype will be removed too.
 Args    : $genotype_id
 Return  :     0 if all is OK
           or: a string error if the genotype has annotations

=cut

sub delete_genotype
{
  my $self = shift;
  my $genotype_id = shift;

  my $schema = $self->curs_schema();

  my $genotype = $schema->resultset('Genotype')->find($genotype_id);

  if ($genotype->annotations()->count() > 0) {
    return "genotype has annotations - delete failed";
  }

  if ($genotype->is_part_of_metagenotype()) {
    return "genotype is part of a metagenotype - delete failed";
  }

  $genotype->delete();

  $self->_remove_unused_alleles();

  return 0;
}

=head2 delete_metagenotype

 Usage   : $utils->delete_metagenotype($genotype_id);
 Function: Remove a metagenotype from the CursDB if it has no annotations.
 Args    : $metagenotype_id
 Return  :     0 if all is OK
           or: a string error if the genotype has annotations

=cut

sub delete_metagenotype
{
  my $self = shift;
  my $metagenotype_id = shift;

  my $schema = $self->curs_schema();

  my $metagenotype = $schema->resultset('Metagenotype')->find($metagenotype_id);

  if ($metagenotype->annotations()->count() > 0) {
    return "metagenotype $metagenotype_id has annotations - delete failed";
  }

  $metagenotype->delete();

  return 0;
}

1;
