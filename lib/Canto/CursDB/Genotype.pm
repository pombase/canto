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

=head2 strain

  data_type: 'text'
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
  "strain",
  { data_type => "text", is_nullable => 1 },
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

=head2 metagenotype_host_genotypes

Type: has_many

Related object: L<Canto::CursDB::Metagenotype>

=cut

__PACKAGE__->has_many(
  "metagenotype_host_genotypes",
  "Canto::CursDB::Metagenotype",
  { "foreign.host_genotype_id" => "self.genotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 metagenotype_pathogen_genotypes

Type: has_many

Related object: L<Canto::CursDB::Metagenotype>

=cut

__PACKAGE__->has_many(
  "metagenotype_pathogen_genotypes",
  "Canto::CursDB::Metagenotype",
  { "foreign.pathogen_genotype_id" => "self.genotype_id" },
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


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-06-26 15:24:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:N+yZI2wo/YL3GJG4/35PEw

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

sub allele_string
{
  my $self = shift;

  return
    join " ", map {
      $_->long_identifier()
    } $self->alleles();
}

sub display_name
{
  my $self = shift;

  return $self->name() || $self->allele_string() || 'wild type';
}

__PACKAGE__->many_to_many('alleles' => 'allele_genotypes',
                          'allele');


# returns either the meta-genotype(s) that this genotype is part of or
# empty list
sub metagenotypes
{
  my $self = shift;

  my @metagenotypes = $self->metagenotype_host_genotypes()->all();

  return @metagenotypes if scalar(@metagenotypes) > 0;

  return $self->metagenotype_pathogen_genotypes()->all();
}

# returns either the count of meta-genotypes that this genotype is part of
sub metagenotype_count
{
  my $self = shift;

  my $count = $self->metagenotype_host_genotypes()->count();

  return $count if $count;

  return $self->metagenotype_pathogen_genotypes()->count();
}

# return true if this genotype is part of a metagenotype
sub is_part_of_metagenotype
{
  my $self = shift;

  if ($self->metagenotype_host_genotypes()->count() > 0) {
    return 1;
  }

  return $self->metagenotype_pathogen_genotypes()->count > 0;
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

sub delete
{
  my $self = shift;

  $self->allele_genotypes()->search({})->delete();

  $self->SUPER::delete();
}

__PACKAGE__->meta->make_immutable;
1;
