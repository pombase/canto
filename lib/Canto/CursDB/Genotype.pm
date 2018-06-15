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

=head2 metagenotype_part_genotypes

Type: has_many

Related object: L<Canto::CursDB::MetagenotypePart>

=cut

__PACKAGE__->has_many(
  "metagenotype_part_genotypes",
  "Canto::CursDB::MetagenotypePart",
  { "foreign.genotype_id" => "self.genotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 metagenotype_part_metagenotypes

Type: has_many

Related object: L<Canto::CursDB::MetagenotypePart>

=cut

__PACKAGE__->has_many(
  "metagenotype_part_metagenotypes",
  "Canto::CursDB::MetagenotypePart",
  { "foreign.metagenotype_id" => "self.genotype_id" },
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


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-06-18 16:58:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kOdEeMmcCgqqdts3LFUokw

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

 Usage   : $gene->feature_type();
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

  return $self->name() || $self->allele_string();
}

__PACKAGE__->many_to_many('alleles' => 'allele_genotypes',
                          'allele');

# returns either the meta-genotype(s) that this genotype is part of or empty list
# this object IS a meta-genotype
sub metagenotypes
{
  my $self = shift;

  my $parts_rs = $self->metagenotype_part_genotypes()->search({}, { prefetch => 'metagenotype' });

  if ($parts_rs->count() > 0) {
    return $parts_rs->search_related('metagenotype')->all();
  } else {
    return [];
  }
}

sub metagenotype_parts
{
  my $self = shift;

  my $options = { prefetch => 'metagenotype' };

  my $parts_rs = $self->metagenotype_part_genotypes()->search({}, $options);

  if ($parts_rs->count() == 0) {
    $parts_rs = $self->metagenotype_part_metagenotypes()->search({}, $options);
  }

  return $parts_rs;
}


=head2

 Usage   : my $type = $genotype->genotype_type();
 Args    : $config - the Config object
 Returns : "normal", "host", "pathogen" or "pathogen-host"

=cut


sub genotype_type
{
  my $self = shift;
  my $config = shift;

  return "metagenotype" if !defined $self->organism_id();

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
