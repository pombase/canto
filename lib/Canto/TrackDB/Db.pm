use utf8;
package Canto::TrackDB::Db;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::Db

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<db>

=cut

__PACKAGE__->table("db");

=head1 ACCESSORS

=head2 db_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 urlprefix

  data_type: 'text'
  is_nullable: 1

=head2 url

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "db_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "urlprefix",
  { data_type => "text", is_nullable => 1 },
  "url",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</db_id>

=back

=cut

__PACKAGE__->set_primary_key("db_id");

=head1 RELATIONS

=head2 dbxrefs

Type: has_many

Related object: L<Canto::TrackDB::Dbxref>

=cut

__PACKAGE__->has_many(
  "dbxrefs",
  "Canto::TrackDB::Dbxref",
  { "foreign.db_id" => "self.db_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:27:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xTlRGTS0hu/WG6rT4IZNvA


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
