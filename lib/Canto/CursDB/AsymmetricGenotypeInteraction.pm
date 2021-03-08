use utf8;
package Canto::CursDB::AsymmetricGenotypeInteraction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::AsymmetricGenotypeInteraction

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<asymmetric_genotype_interaction>

=cut

__PACKAGE__->table("asymmetric_genotype_interaction");

=head1 ACCESSORS

=head2 asymmetric_genotype_interaction_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 interaction_type

  data_type: 'text'
  is_nullable: 0

=head2 primary_annotation_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 genotype_a_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 genotype_annotation_b_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "asymmetric_genotype_interaction_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "interaction_type",
  { data_type => "text", is_nullable => 0 },
  "primary_annotation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "genotype_a_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "genotype_annotation_b_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</asymmetric_genotype_interaction_id>

=back

=cut

__PACKAGE__->set_primary_key("asymmetric_genotype_interaction_id");

=head1 RELATIONS

=head2 genotype_a

Type: belongs_to

Related object: L<Canto::CursDB::Genotype>

=cut

__PACKAGE__->belongs_to(
  "genotype_a",
  "Canto::CursDB::Genotype",
  { genotype_id => "genotype_a_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 genotype_annotation_b

Type: belongs_to

Related object: L<Canto::CursDB::GenotypeAnnotation>

=cut

__PACKAGE__->belongs_to(
  "genotype_annotation_b",
  "Canto::CursDB::GenotypeAnnotation",
  { genotype_annotation_id => "genotype_annotation_b_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 primary_annotation

Type: belongs_to

Related object: L<Canto::CursDB::GenotypeAnnotation>

=cut

__PACKAGE__->belongs_to(
  "primary_annotation",
  "Canto::CursDB::GenotypeAnnotation",
  { genotype_annotation_id => "primary_annotation_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-04-07 17:02:35
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jogJ3bsSF2C4tAqFsmPZHg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
