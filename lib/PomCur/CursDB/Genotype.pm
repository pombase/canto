use utf8;
package PomCur::CursDB::Genotype;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PomCur::CursDB::Genotype

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

=head2 primary_identifier

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "genotype_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "primary_identifier",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</genotype_id>

=back

=cut

__PACKAGE__->set_primary_key("genotype_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<primary_identifier_unique>

=over 4

=item * L</primary_identifier>

=back

=cut

__PACKAGE__->add_unique_constraint("primary_identifier_unique", ["primary_identifier"]);

=head1 RELATIONS

=head2 allele_genotypes

Type: has_many

Related object: L<PomCur::CursDB::AlleleGenotype>

=cut

__PACKAGE__->has_many(
  "allele_genotypes",
  "PomCur::CursDB::AlleleGenotype",
  { "foreign.genotype" => "self.genotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 genotype_annotations

Type: has_many

Related object: L<PomCur::CursDB::GenotypeAnnotation>

=cut

__PACKAGE__->has_many(
  "genotype_annotations",
  "PomCur::CursDB::GenotypeAnnotation",
  { "foreign.genotype" => "self.genotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-07-29 18:14:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cgM8mi8zb5UIM4CTQWHVgQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
