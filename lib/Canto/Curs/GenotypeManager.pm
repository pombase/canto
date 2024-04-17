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

sub allele_hashes_in_config_order
{
  my $config = shift;
  my @allele_hashes = @_;

  my %allele_type_order = ();

  for (my $idx = 0; $idx < @{$config->{allele_type_list}}; $idx++) {
    my $allele_config = $config->{allele_type_list}->[$idx];

    $allele_type_order{$allele_config->{name}} = $idx;
  }

  my $sorter = sub {
    my $a = shift;
    my $b = shift;

    if (!defined $a->{type} && !defined $b->{type}) {
      return 0;
    }

    if (!defined $a->{type}) {
      return -1;
    }

    if (!defined $b->{type}) {
      return 1;
    }

    my $res =
      ($allele_type_order{$a->{type}} // 0)
        <=>
      ($allele_type_order{$b->{type}} // 0);

    if ($res == 0) {
      my $a_name = $a->{name};
      my $a_description = $a->{description};
      my $a_type = $a->{type};
      my $a_expression = $a->{expression};
      my $a_promoter_gene = $a->{promoter_gene};

      my $b_name = $b->{name};
      my $b_description = $b->{description};
      my $b_type = $b->{type};
      my $b_expression = $b->{expression};
      my $b_promoter_gene = $b->{promoter_gene};

      "$a_name-$a_description-$a_type-$a_expression-$a_promoter_gene"
        cmp
      "$b_name-$b_description-$b_type-$b_expression-$b_promoter_gene"
    } else {
      $res;
    }
  };

  return sort { $sorter->($a, $b) } @allele_hashes;
}

sub _allele_string_from_json
{
  my $config = shift;
  my $curs_key = shift;
  my $allele_manager = shift;
  my $allele_data = shift;

  my @allele_data_copy = map {
    my $allele_hash = $_;

    my %ret = %$allele_hash;

    my $allele = $allele_manager->allele_from_json($allele_hash, $curs_key);

    $ret{name} = $allele->name() // 'UNKNOWN';
    $ret{description} = $allele->description() // 'UNKNOWN';
    $ret{type} = $allele->type() // 'UNKNOWN';
    $ret{expression} = $allele->expression() // 'UNKNOWN';
    $ret{promoter_gene} = $allele->promoter_gene() // 'UNKNOWN';

    $ret{allele} = $allele;

    \%ret;
  } @$allele_data;

  @allele_data_copy = allele_hashes_in_config_order($config, @allele_data_copy);

  my %diploid_groups= ();

  my @haploids = ();

  for my $allele_data (@allele_data_copy) {
    if ($allele_data->{diploid_name}) {
      push @{$diploid_groups{$allele_data->{diploid_name}}}, $allele_data->{allele};
    } else {
      push @haploids, $allele_data->{allele};
    }
  }

  my @group_names = ();

  my $_make_allele_display_name = sub {
    my $allele = shift;
    my $gene = $allele->gene();
    my $long_id = $allele->long_identifier($config);
    my $type = '<' . $allele->type() . '>';
    $long_id .= $type;
    if ($gene) {
      return $long_id . '-' . $gene->primary_identifier();
    } else {
      return $long_id;
    }
  };

  my @diploid_group_names = ();

  for my $diploid_name (sort keys %diploid_groups) {
    push @diploid_group_names, (join ' / ',
                                map {
                                  my $allele = $_;
                                  $_make_allele_display_name->($allele);
                                } @{$diploid_groups{$diploid_name}});
  }

  my @haploid_names = map { $_make_allele_display_name->($_) } @haploids;

  return join " ", (@diploid_group_names, @haploid_names);
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
  my $search_alleles_data = shift;

  my $schema = $self->curs_schema();
  my $curs_key = $self->curs_key();

  my $allele_manager =
    Canto::Curs::AlleleManager->new(config => $self->config(),
                                    curs_schema => $schema);

  my $search_allele_string =
    _allele_string_from_json($self->config(), $curs_key, $allele_manager,
                             $search_alleles_data);

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

    next if scalar(@alleles) != scalar(@$search_alleles_data);

    if ($search_allele_string eq $genotype->allele_string($self->config(), 1, 1)) {
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

  $alleles_with_no_genotype_rs->search_related('allelesynonyms')->delete();
  $alleles_with_no_genotype_rs->search_related('allele_notes')->delete();

  $alleles_with_no_genotype_rs->delete();
}

sub _remove_unused_diploids
{
  my $self = shift;

  my $where = "diploid_id NOT IN (SELECT diploid FROM allele_genotype " .
    "where allele_genotype.diploid is not null)";

  my $diploids_with_no_genotype_rs =
    $self->curs_schema()->resultset('Diploid')
         ->search({},
                  {
                    where => \$where,
                  });

  $diploids_with_no_genotype_rs->delete();
}

sub _set_genotype_alleles
{
  my $self = shift;
  my $genotype = shift;
  my $alleles = shift;
  my $new_identifier_prefix = shift;

  my $schema = $self->curs_schema();
  my $curs_key = $self->curs_key();

  $genotype->set_alleles([]);

  $self->_remove_unused_alleles();
  $self->_remove_unused_diploids();

  my $allele_manager =
    Canto::Curs::AlleleManager->new(config => $self->config(),
                                    curs_schema => $schema);

  my @haploid_alleles = ();

  my %diploid_groups = ();

  for my $allele_data (@$alleles) {
    my $allele = $allele_manager->allele_from_json($allele_data, $curs_key);

    if ($allele_data->{diploid_name}) {
      push @{$diploid_groups{$allele_data->{diploid_name}}}, $allele;
    } else {
      push @haploid_alleles, $allele;
    }
  }

  my @diploid_groups = ();

  while (my ($diploid_name, $diploid_alleles) = each %diploid_groups) {
    push @diploid_groups, $diploid_alleles;
  }

  $genotype->set_alleles(\@haploid_alleles);

  for my $group (@diploid_groups) {
    my @group_alleles = @$group;
    my $diploid_name = $new_identifier_prefix . '-' . join "--",
      sort map {
        my $allele = $_;
        $allele->primary_identifier();
      } @group_alleles;

    my $diploid = $schema->create_with_type('Diploid',
                                            {
                                              name => $diploid_name,
                                            });

    map {
      my $allele = $_;

      my %create_args = (
        allele => $allele->allele_id(),
        genotype => $genotype->genotype_id(),
        diploid => $diploid->diploid_id(),
      );

      $schema->create_with_type('AlleleGenotype', \%create_args);
    } @group_alleles;
  }

}

=head2 make_genotype

 Usage   : $genotype_manager->make_genotype($name, $background, \@allele_objects,
                                            $genotype_taxonid, $identifier, $strain_name,
                                            $comment, \@diploid_groups);
 Function: Create a Genotype object in the CursDB
 Args    : $name - the name for the new object
           $background
           \@alleles - a list of JSON details for the alleles
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

  $self->_set_genotype_alleles($genotype, $alleles, $new_identifier);

  if ($strain_name) {
    my $strain = $self->strain_manager()->find_strain_by_name($genotype_taxonid, $strain_name);
    $genotype->strain($strain);
  }

  $genotype->update();

  return $genotype;
}


=head2 find_or_make_genotype

 Usage   : my $genotype = $manager->find_or_make_genotype($taxon_id, $background,
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

sub find_or_make_genotype
{
  my $self = shift;

  my $genotype_taxonid = shift;
  my $background = shift;
  my $strain_name = shift;
  my $allele_data = shift;

  my $genotype = $self->find_genotype($genotype_taxonid, $background,
                                      $strain_name, $allele_data);

  if (!defined $genotype) {
    $genotype =
      $self->make_genotype(undef, $background,
                           $allele_data, $genotype_taxonid, undef,
                           undef, undef);
  }

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
    $identifier .= '-' . ($strain_name =~ s/ /-/gr);
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

 Usage   : # make a pathogen-host metagenotype:
           my $metagenotype =
             $genotype_manager->make_metagenotype(host_genotype => $host_genotype,
                                                  pathogen_genotype => $pathogen_genotype);
    Or   : # make an interaction:
           my $metagenotype =
             $genotype_manager->make_metagenotype(interactor_a => $interactor_a,
                                                  interactor_b => $interactor_b);
 Function: Create a metagenotype from it's parts

=cut

sub make_metagenotype
{
  my $self = shift;

  my %args = @_;

  my $organism_lookup = Canto::Track::get_adaptor($self->config(), 'organism');

  my $metagenotype_identifier = $self->_get_metagenotype_identifier();

  my %create_args = (identifier => $metagenotype_identifier);

  my $host_genotype = $args{host_genotype};
  my $pathogen_genotype = $args{pathogen_genotype};

  if ($host_genotype && $pathogen_genotype) {
    my $host_details =
      $organism_lookup->lookup_by_taxonid($host_genotype->organism()->taxonid());

    if ($host_details->{pathogen_or_host} ne 'host') {
      die "organism of genotype passed with the 'host' arg isn't a host: " .
        $host_details->{pathogen_or_host};
    }

    my $pathogen_details =
      $organism_lookup->lookup_by_taxonid($pathogen_genotype->organism()->taxonid());

    if ($pathogen_details->{pathogen_or_host} ne 'pathogen') {
      die "organism of genotype passed with the 'pathogen' arg isn't a pathogen: " .
        $pathogen_details->{pathogen_or_host};
    }

    $create_args{type} = 'pathogen-host';
    $create_args{first_genotype_id} = $pathogen_genotype->genotype_id();
    $create_args{second_genotype_id} = $host_genotype->genotype_id();
  } else {
    my $interactor_a = $args{interactor_a};
    if (!$interactor_a) {
      die "missing interactor_a in call to make_metagenotype()";
    }

    my $interactor_b = $args{interactor_b};
    if (!$interactor_b) {
      die "missing interactor_a in call to make_metagenotype()";
    }

    $create_args{type} = 'interaction';
    $create_args{first_genotype_id} = $interactor_a->genotype_id();
    $create_args{second_genotype_id} = $interactor_b->genotype_id();
  }

  my $schema = $self->curs_schema();

  my $metagenotype = $schema->create_with_type('Metagenotype', \%create_args);
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
           \@allele_objects - details of Allele objects to attach to the new
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
  my $alleles_data = shift;
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

  $self->_set_genotype_alleles($genotype, $alleles_data, $genotype->identifier());

  if ($strain_name) {
    my $strain = $self->strain_manager()->find_strain_by_name($genotype_taxonid, $strain_name);
    $genotype->strain($strain);
  }

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

  my $name = $chado_genotype_details->{name};
  my $background = $chado_genotype_details->{background};
  my $identifier = $chado_genotype_details->{identifier};

  return $self->make_genotype($name, $background, \@alleles_data,
                              $chado_genotype_details->{organism}->{taxonid},
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

  my $first_genotype_id;

  if ($args{pathogen_genotype}) {
    $first_genotype_id = $args{pathogen_genotype}->genotype_id();
  } else {
    $first_genotype_id = $args{interactor_a}->genotype_id();
  }

  my $second_genotype_id;

  if ($args{host_genotype}){
    $second_genotype_id = $args{host_genotype}->genotype_id();
  } else {
    $second_genotype_id = $args{interactor_b}->genotype_id();
  }

  my $schema = $self->curs_schema();

  my %search_args = (
    first_genotype_id => $first_genotype_id,
    second_genotype_id => $second_genotype_id,
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

  if ($genotype->genotype_interaction_genotype_bs()->count() > 0 ||
      $genotype->genotype_interaction_genotypes_a()->count() > 0 ||
      $genotype->genotype_interactions_with_phenotype()->count() > 0) {
    return "this genotype is part of a interaction so can't be deleted";
  }

  if ($genotype->annotations()->count() > 0) {
    return "genotype has annotations - delete failed";
  }

  if ($genotype->is_part_of_metagenotype()) {
    my $metagenotype = ($genotype->metagenotypes())[0];

    my $type;

    if ($metagenotype->type() eq 'pathogen-host') {
      $type = 'pathogen-host metagenotype';
    } else {
      $type = $metagenotype->type();
    }

    return "genotype is part of a $type - delete failed";
  }

  $genotype->delete();

  $self->_remove_unused_alleles();
  $self->_remove_unused_diploids();

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

  my $annotation_rs = $schema->resultset('Annotation');
  while (defined (my $annotation = $annotation_rs->next())) {
    my $extension = $annotation->data()->{extension};
    if (defined $extension) {
      map {
        my $or_part = $_;
        map {
          my $and_part = $_;
          my $is_metagenotype_extension = (
            $and_part->{rangeType}
            && $and_part->{rangeType} eq 'Metagenotype'
          );
          if ($is_metagenotype_extension) {
            my $rangeValue = $and_part->{rangeValue};
            if ($rangeValue == $metagenotype_id) {
              return "metagenotype $metagenotype_id used in extensions - delete failed";
            }
          }
        } @$or_part;
      } @$extension;
    }
  }

  my $host_genotype = $metagenotype->host_genotype();
  my $pathogen_genotype = $metagenotype->pathogen_genotype();

  $metagenotype->delete();

  if ($pathogen_genotype->annotations()->count() == 0 &&
        $pathogen_genotype->is_wild_type() &&
        !$pathogen_genotype->is_part_of_metagenotype()) {
    $self->delete_genotype($pathogen_genotype->genotype_id());
  }

  if ($host_genotype->annotations()->count() == 0 &&
        $host_genotype->is_wild_type() &&
        !$host_genotype->is_part_of_metagenotype()) {
    $self->delete_genotype($host_genotype->genotype_id());
  }

  return 0;
}

1;
