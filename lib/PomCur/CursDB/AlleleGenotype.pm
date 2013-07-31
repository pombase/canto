use utf8;
package PomCur::CursDB::AlleleGenotype;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PomCur::CursDB::AlleleGenotype

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<allele_genotype>

=cut

__PACKAGE__->table("allele_genotype");

=head1 ACCESSORS

=head2 allele_genotype_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 allele

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 genotype

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "allele_genotype_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "allele",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "genotype",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</allele_genotype_id>

=back

=cut

__PACKAGE__->set_primary_key("allele_genotype_id");

=head1 RELATIONS

=head2 allele

Type: belongs_to

Related object: L<PomCur::CursDB::Allele>

=cut

__PACKAGE__->belongs_to(
  "allele",
  "PomCur::CursDB::Allele",
  { allele_id => "allele" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 genotype

Type: belongs_to

Related object: L<PomCur::CursDB::Genotype>

=cut

__PACKAGE__->belongs_to(
  "genotype",
  "PomCur::CursDB::Genotype",
  { genotype_id => "genotype" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-07-29 18:14:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6Lht0BAC0X87v9kvShRuwQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
