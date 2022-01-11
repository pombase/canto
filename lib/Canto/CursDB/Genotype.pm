use utf8;
package Canto::CursDB::Genotype;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::Genotype

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<genotype>

=cut

__PACKAGE__->table("genotype");

=head1 ACCESSORS

=head2 genotype_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 identifier

  data_type: 'text'
  is_nullable: 0

=head2 background

  data_type: 'text'
  is_nullable: 1

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 strain_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 organism_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 name

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "genotype_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "identifier",
  { data_type => "text", is_nullable => 0 },
  "background",
  { data_type => "text", is_nullable => 1 },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "strain_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "organism_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "name",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</genotype_id>

=back

=cut

__PACKAGE__->set_primary_key("genotype_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<identifier_unique>

=over 4

=item * L</identifier>

=back

=cut

__PACKAGE__->add_unique_constraint("identifier_unique", ["identifier"]);

=head2 C<name_unique>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name_unique", ["name"]);

=head1 RELATIONS

=head2 allele_genotypes

Type: has_many

Related object: L<Canto::CursDB::AlleleGenotype>

=cut

__PACKAGE__->has_many(
  "allele_genotypes",
  "Canto::CursDB::AlleleGenotype",
  { "foreign.genotype" => "self.genotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 directional_genotype_interactions

Type: has_many

Related object: L<Canto::CursDB::DirectionalGenotypeInteraction>

=cut

__PACKAGE__->has_many(
  "directional_genotype_interactions",
  "Canto::CursDB::DirectionalGenotypeInteraction",
  { "foreign.genotype_a_id" => "self.genotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 genotype_annotations

Type: has_many

Related object: L<Canto::CursDB::GenotypeAnnotation>

=cut

__PACKAGE__->has_many(
  "genotype_annotations",
  "Canto::CursDB::GenotypeAnnotation",
  { "foreign.genotype" => "self.genotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 metagenotype_first_genotypes

Type: has_many

Related object: L<Canto::CursDB::Metagenotype>

=cut

__PACKAGE__->has_many(
  "metagenotype_first_genotypes",
  "Canto::CursDB::Metagenotype",
  { "foreign.first_genotype_id" => "self.genotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 metagenotype_second_genotypes

Type: has_many

Related object: L<Canto::CursDB::Metagenotype>

=cut

__PACKAGE__->has_many(
  "metagenotype_second_genotypes",
  "Canto::CursDB::Metagenotype",
  { "foreign.second_genotype_id" => "self.genotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organism

Type: belongs_to

Related object: L<Canto::CursDB::Organism>

=cut

__PACKAGE__->belongs_to(
  "organism",
  "Canto::CursDB::Organism",
  { organism_id => "organism_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 strain

Type: belongs_to

Related object: L<Canto::CursDB::Strain>

=cut

__PACKAGE__->belongs_to(
  "strain",
  "Canto::CursDB::Strain",
  { strain_id => "strain_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 symmetric_genotype_interaction_genotype_bs

Type: has_many

Related object: L<Canto::CursDB::SymmetricGenotypeInteraction>

=cut

__PACKAGE__->has_many(
  "symmetric_genotype_interaction_genotype_bs",
  "Canto::CursDB::SymmetricGenotypeInteraction",
  { "foreign.genotype_b_id" => "self.genotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 symmetric_genotype_interaction_genotypes_a

Type: has_many

Related object: L<Canto::CursDB::SymmetricGenotypeInteraction>

=cut

__PACKAGE__->has_many(
  "symmetric_genotype_interaction_genotypes_a",
  "Canto::CursDB::SymmetricGenotypeInteraction",
  { "foreign.genotype_a_id" => "self.genotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-04-09 14:18:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lp7PW60LHxXBB3qcZeaEZw

=head2 annotations

 Usage   : my $annotation_rs = $genotype->annotations();
 Function: Return the Annotations object related to this genotype via the
           genotype_annotations table
 Args    : None
 Returns : An Annotation ResultSet

=cut

__PACKAGE__->many_to_many('annotations' => 'genotype_annotations',
                          'annotation');

=head2 feature_id

 Usage   : $genotype->feature_id()
 Function: Return the genotype_id of this genotype.  This is an alias for
           genotype_id() that exists to make gene and genotype handling easier.

=cut

sub feature_id
{
  my $self = shift;

  return $self->genotype_id();
}

=head2 feature_type

 Usage   : $genotype->feature_type();
 Function: Return 'genotype'.  This exists to make gene and genotype handling
           easier.

=cut

sub feature_type
{
  return 'genotype';
}

# aliases to make Genotype look like Gene
sub all_annotations
{
  my $self = shift;

  return $self->annotations();
}

sub alleles_in_config_order
{
  my $self = shift;
  my $config = shift;

  my %allele_type_order = ();

  for (my $idx = 0; $idx < @{$config->{allele_type_list}}; $idx++) {
    my $allele_config = $config->{allele_type_list}->[$idx];

    $allele_type_order{$allele_config->{name}} = $idx;
  }

  my $allele_genotype_rs = $self->allele_genotypes()
    ->search({},
             {
               prefetch => [qw[diploid allele]]
             });

  my $_secondary_sort = sub {
    my $a = shift;
    my $b = shift;

    my $a_name = $a->name() // 'UNKNOWN';
    my $a_description = $a->description() // 'UNKNOWN';
    my $a_type = $a->type() // 'UNKNOWN';
    my $a_expression = $a->expression() // 'UNKNOWN';

    my $b_name = $b->name() // 'UNKNOWN';
    my $b_description = $b->description() // 'UNKNOWN';
    my $b_type = $b->type() // 'UNKNOWN';
    my $b_expression = $b->expression() // 'UNKNOWN';

    "$a_name-$a_description-$a_type-$a_expression"
      cmp
    "$b_name-$b_description-$b_type-$b_expression"
  };

  my $sorter = sub {
    my $a = shift->allele();
    my $b = shift->allele();

    if (!defined $a->type() && !defined $b->type()) {
      return $_secondary_sort($a, $b);
    }

    if (!defined $a->type()) {
      return -1;
    }

    if (!defined $b->type()) {
      return 1;
    }

    my $res =
      ($allele_type_order{$a->type()} // 0)
        <=>
      ($allele_type_order{$b->type()} // 0);

    if ($res == 0) {
      $_secondary_sort->($a, $b)
    } else {
      $res;
    }
  };

  return sort { $sorter->($a, $b) } $allele_genotype_rs->all();
}

sub allele_string
{
  my $self = shift;
  my $config = shift;
  my $add_gene_primary_identifer = shift;
  my $include_type = shift;

  my %diploid_groups = ();

  my @alleles_in_config_order = $self->alleles_in_config_order($config);

  my @haploids = ();

  for my $row (@alleles_in_config_order) {
    my $allele = $row->allele();
    my $diploid = $row->diploid();
    if ($diploid) {
      push @{$diploid_groups{$diploid->name()}}, $allele;
    } else {
      push @haploids, $row->allele();
    }
  }

  my @group_names = ();

  my $_make_group_name = sub {
    my $allele = shift;

    my $long_id = $allele->long_identifier($config);
    if ($include_type) {
      my $type = '<' . $allele->type() . '>';
      $long_id .= $type;
    }
    my $gene = $allele->gene();
    if ($add_gene_primary_identifer && $gene) {
      return $long_id . '-' . $gene->primary_identifier();
    } else {
      return $long_id;
    }
  };

  for my $group_name (sort keys %diploid_groups) {
    push @group_names, (join ' / ',
                        map {
                          my $allele = $_;
                          $_make_group_name->($allele);
                        } @{$diploid_groups{$group_name}});
  }

  return join " ", (@group_names, map { $_make_group_name->($_) } @haploids);
}

sub display_name
{
  my $self = shift;
  my $config = shift;
  my $strain_name = shift;

  my $display_name = $self->name() || $self->allele_string($config) || 'wild type';

  if ($strain_name) {
    $display_name .= " ($strain_name)";
  }

  return $display_name;
}

__PACKAGE__->many_to_many('alleles' => 'allele_genotypes',
                          'allele');


# returns either the metagenotype(s) that this genotype is part of or
# empty list
sub metagenotypes
{
  my $self = shift;

  my @metagenotypes = $self->metagenotype_first_genotypes()->all();

  return @metagenotypes if scalar(@metagenotypes) > 0;

  return $self->metagenotype_second_genotypes()->all();
}

# returns a hash of counts of metagenotypes of this genotype by
# metagenotype type
sub metagenotype_count_by_type
{
  my $self = shift;

  my %ret = ();

  my $rs = $self->metagenotype_first_genotypes();

  while (defined (my $metagenotype = $rs->next())) {
    $ret{$metagenotype->type()}++;
  }

  $rs = $self->metagenotype_second_genotypes();

  while (defined (my $metagenotype = $rs->next())) {
    $ret{$metagenotype->type()}++;
  }

  return %ret;
}

# return true if this genotype is part of a metagenotype
sub is_part_of_metagenotype
{
  my $self = shift;

  if ($self->metagenotype_first_genotypes()->count() > 0) {
    return 1;
  }

  return $self->metagenotype_second_genotypes()->count > 0;
}

=head2

 Usage   : my $type = $genotype->genotype_type();
 Args    : $config - the Config object
 Returns : "normal", "host" or "pathogen"

=cut

sub genotype_type
{
  my $self = shift;
  my $config = shift;

  my $genotype_organism = $self->organism();

  my $org_lookup = Canto::Track::get_adaptor($config, 'organism');
  my $organism_details = $org_lookup->lookup_by_taxonid($genotype_organism->taxonid());

  if ($organism_details->{pathogen_or_host} eq 'unknown') {
    return "normal"
  } else {
    return $organism_details->{pathogen_or_host};
  }
}

=head2 is_wild_type

 Usage   : if ($genotype->is_wild_type()) { ... }
 Function: Return 1 iff is genotype has no alleles

=cut

sub is_wild_type {
  my $self = shift;

  return $self->allele_genotypes()->count() == 0;
}


sub delete
{
  my $self = shift;

  $self->allele_genotypes()->search({})->delete();

  map {
    $_->delete();
  } $self->metagenotypes();


  $self->SUPER::delete();
}

__PACKAGE__->meta->make_immutable;
1;
