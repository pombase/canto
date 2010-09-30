package PomCur::CursDB::Gene;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::CursDB::Gene

=cut

__PACKAGE__->table("gene");

=head1 ACCESSORS

=head2 gene_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 primary_identifier

  data_type: 'text'
  is_nullable: 0

=head2 primary_name

  data_type: 'text'
  is_nullable: 1

=head2 product

  data_type: 'text'
  is_nullable: 1

=head2 organism

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "gene_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "primary_identifier",
  { data_type => "text", is_nullable => 0 },
  "primary_name",
  { data_type => "text", is_nullable => 1 },
  "product",
  { data_type => "text", is_nullable => 1 },
  "organism",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("gene_id");
__PACKAGE__->add_unique_constraint("primary_identifier_unique", ["primary_identifier"]);

=head1 RELATIONS

=head2 organism

Type: belongs_to

Related object: L<PomCur::CursDB::Organism>

=cut

__PACKAGE__->belongs_to(
  "organism",
  "PomCur::CursDB::Organism",
  { organism_id => "organism" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-09-30 16:18:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2z89CNxMRrzIgFWE4jEBIA

use Moose;

with 'PomCur::Role::GeneNames';

# You can replace this text with custom content, and it will be preserved on regeneration
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
