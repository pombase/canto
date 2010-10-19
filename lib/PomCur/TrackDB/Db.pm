package PomCur::TrackDB::Db;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::TrackDB::Db

=cut

__PACKAGE__->table("db");

=head1 ACCESSORS

=head2 db_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'character varying'
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'character varying'
  is_nullable: 1
  size: 255

=head2 urlprefix

  data_type: 'character varying'
  is_nullable: 1
  size: 255

=head2 url

  data_type: 'character varying'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "db_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "character varying", is_nullable => 0, size => 255 },
  "description",
  { data_type => "character varying", is_nullable => 1, size => 255 },
  "urlprefix",
  { data_type => "character varying", is_nullable => 1, size => 255 },
  "url",
  { data_type => "character varying", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("db_id");

=head1 RELATIONS

=head2 dbxrefs

Type: has_many

Related object: L<PomCur::TrackDB::Dbxref>

=cut

__PACKAGE__->has_many(
  "dbxrefs",
  "PomCur::TrackDB::Dbxref",
  { "foreign.db_id" => "self.db_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-10-19 16:02:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cLW/yowA9M9Mqn92xzTRxQ


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
