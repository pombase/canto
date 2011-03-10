package PomCur::CursDB::GeneAnnotation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::CursDB::GeneAnnotation

=cut

__PACKAGE__->table("gene_annotation");

=head1 ACCESSORS

=head2 gene_annotation_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 gene

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 annotation

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "gene_annotation_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "gene",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "annotation",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("gene_annotation_id");

=head1 RELATIONS

=head2 annotation

Type: belongs_to

Related object: L<PomCur::CursDB::Annotation>

=cut

__PACKAGE__->belongs_to(
  "annotation",
  "PomCur::CursDB::Annotation",
  { annotation_id => "annotation" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 gene

Type: belongs_to

Related object: L<PomCur::CursDB::Gene>

=cut

__PACKAGE__->belongs_to(
  "gene",
  "PomCur::CursDB::Gene",
  { gene_id => "gene" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-10-11 13:37:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:txxGvY3eugpHSZBTfl2Qew


__PACKAGE__->meta->make_immutable;

1;
