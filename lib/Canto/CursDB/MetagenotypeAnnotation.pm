use utf8;
package Canto::CursDB::MetagenotypeAnnotation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::MetagenotypeAnnotation

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<metagenotype_annotation>

=cut

__PACKAGE__->table("metagenotype_annotation");

=head1 ACCESSORS

=head2 metagenotype_annotation_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 metagenotype

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 annotation

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "metagenotype_annotation_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "metagenotype",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "annotation",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</metagenotype_annotation_id>

=back

=cut

__PACKAGE__->set_primary_key("metagenotype_annotation_id");

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

=head2 metagenotype

Type: belongs_to

Related object: L<Canto::CursDB::Metagenotype>

=cut

__PACKAGE__->belongs_to(
  "metagenotype",
  "Canto::CursDB::Metagenotype",
  { metagenotype_id => "metagenotype" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-06-26 15:30:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SW392sb3loWfO9huogGY7Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
