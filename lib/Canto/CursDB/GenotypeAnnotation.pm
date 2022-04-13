use utf8;
package Canto::CursDB::GenotypeAnnotation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::GenotypeAnnotation

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<genotype_annotation>

=cut

__PACKAGE__->table("genotype_annotation");

=head1 ACCESSORS

=head2 genotype_annotation_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 genotype

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 annotation

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "genotype_annotation_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "genotype",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "annotation",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</genotype_annotation_id>

=back

=cut

__PACKAGE__->set_primary_key("genotype_annotation_id");

=head1 RELATIONS

=head2 annotation

Type: belongs_to

Related object: L<Canto::CursDB::Annotation>

=cut

__PACKAGE__->belongs_to(
  "annotation",
  "Canto::CursDB::Annotation",
  { annotation_id => "annotation" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 genotype

Type: belongs_to

Related object: L<Canto::CursDB::Genotype>

=cut

__PACKAGE__->belongs_to(
  "genotype",
  "Canto::CursDB::Genotype",
  { genotype_id => "genotype" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 genotype_interactions

Type: has_many

Related object: L<Canto::CursDB::GenotypeInteraction>

=cut

__PACKAGE__->has_many(
  "genotype_interactions",
  "Canto::CursDB::GenotypeInteraction",
  {
    "foreign.primary_genotype_annotation_id" => "self.genotype_annotation_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 genotype_interactions_with_phenotype_genotype_annotation_a

Type: has_many

Related object: L<Canto::CursDB::GenotypeInteractionWithPhenotype>

=cut

__PACKAGE__->has_many(
  "genotype_interactions_with_phenotype_genotype_annotation_a",
  "Canto::CursDB::GenotypeInteractionWithPhenotype",
  {
    "foreign.genotype_annotation_a_id" => "self.genotype_annotation_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 genotype_interactions_with_phenotype_primary_genotype_annotation

Type: has_many

Related object: L<Canto::CursDB::GenotypeInteractionWithPhenotype>

=cut

__PACKAGE__->has_many(
  "genotype_interactions_with_phenotype_primary_genotype_annotation",
  "Canto::CursDB::GenotypeInteractionWithPhenotype",
  {
    "foreign.primary_genotype_annotation_id" => "self.genotype_annotation_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-04-12 16:57:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:o+PTBmw2jIhZ7M/LZLUWDQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
