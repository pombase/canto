package PomCur::ChadoDB::Dbxrefprop;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::ChadoDB::Dbxrefprop

=head1 DESCRIPTION

Metadata about a dbxref. Note that this is not defined in the dbxref module, as it depends on the cvterm table. This table has a structure analagous to cvtermprop.

=cut

__PACKAGE__->table("dbxrefprop");

=head1 ACCESSORS

=head2 dbxrefprop_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'dbxrefprop_dbxrefprop_id_seq'

=head2 dbxref_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 value

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "dbxrefprop_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dbxrefprop_dbxrefprop_id_seq",
  },
  "dbxref_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("dbxrefprop_id");
__PACKAGE__->add_unique_constraint("dbxrefprop_c1", ["dbxref_id", "type_id", "rank"]);

=head1 RELATIONS

=head2 type

Type: belongs_to

Related object: L<PomCur::ChadoDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "PomCur::ChadoDB::Cvterm",
  { cvterm_id => "type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 dbxref

Type: belongs_to

Related object: L<PomCur::ChadoDB::Dbxref>

=cut

__PACKAGE__->belongs_to(
  "dbxref",
  "PomCur::ChadoDB::Dbxref",
  { dbxref_id => "dbxref_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8BmEcCp8IJZzyUI+SpYDzw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
