use utf8;
package Canto::CursDB::MetagenotypePart;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::MetagenotypePart

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<metagenotype_part>

=cut

__PACKAGE__->table("metagenotype_part");

=head1 ACCESSORS

=head2 metagenotype_part_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 metagenotype_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 is_host_part

  data_type: 'boolean'
  is_nullable: 0

=head2 organism_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 genotype_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "metagenotype_part_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "metagenotype_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "is_host_part",
  { data_type => "boolean", is_nullable => 0 },
  "organism_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "genotype_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</metagenotype_part_id>

=back

=cut

__PACKAGE__->set_primary_key("metagenotype_part_id");

=head1 RELATIONS

=head2 genotype

Type: belongs_to

Related object: L<Canto::CursDB::Genotype>

=cut

__PACKAGE__->belongs_to(
  "genotype",
  "Canto::CursDB::Genotype",
  { genotype_id => "genotype_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 metagenotype

Type: belongs_to

Related object: L<Canto::CursDB::Genotype>

=cut

__PACKAGE__->belongs_to(
  "metagenotype",
  "Canto::CursDB::Genotype",
  { genotype_id => "metagenotype_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 organism

Type: belongs_to

Related object: L<Canto::CursDB::Organism>

=cut

__PACKAGE__->belongs_to(
  "organism",
  "Canto::CursDB::Organism",
  { organism_id => "organism_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-06-15 13:48:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OTKGUxQ+VspHO04PLrZJMA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
