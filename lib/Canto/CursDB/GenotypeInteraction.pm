use utf8;
package Canto::CursDB::GenotypeInteraction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::GenotypeInteraction

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<genotype_interaction>

=cut

__PACKAGE__->table("genotype_interaction");

=head1 ACCESSORS

=head2 genotype_interaction_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 interaction_type

  data_type: 'text'
  is_nullable: 0

=head2 primary_genotype_annotation_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 genotype_a_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 genotype_b_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "genotype_interaction_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "interaction_type",
  { data_type => "text", is_nullable => 0 },
  "primary_genotype_annotation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "genotype_a_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "genotype_b_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</genotype_interaction_id>

=back

=cut

__PACKAGE__->set_primary_key("genotype_interaction_id");

=head1 RELATIONS

=head2 genotype_a

Type: belongs_to

Related object: L<Canto::CursDB::Genotype>

=cut

__PACKAGE__->belongs_to(
  "genotype_a",
  "Canto::CursDB::Genotype",
  { genotype_id => "genotype_a_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 genotype_b

Type: belongs_to

Related object: L<Canto::CursDB::Genotype>

=cut

__PACKAGE__->belongs_to(
  "genotype_b",
  "Canto::CursDB::Genotype",
  { genotype_id => "genotype_b_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 primary_genotype_annotation

Type: belongs_to

Related object: L<Canto::CursDB::GenotypeAnnotation>

=cut

__PACKAGE__->belongs_to(
  "primary_genotype_annotation",
  "Canto::CursDB::GenotypeAnnotation",
  { genotype_annotation_id => "primary_genotype_annotation_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-04-12 16:56:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:S2lgQ/lO4BrCGLaUemu92A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
