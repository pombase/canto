use utf8;
package Canto::CursDB::Metadata;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::Metadata

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<metadata>

=cut

__PACKAGE__->table("metadata");

=head1 ACCESSORS

=head2 metadata_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 key

  data_type: 'text'
  is_nullable: 0

=head2 value

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "metadata_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "key",
  { data_type => "text", is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</metadata_id>

=back

=cut

__PACKAGE__->set_primary_key("metadata_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<key_unique>

=over 4

=item * L</key>

=back

=cut

__PACKAGE__->add_unique_constraint("key_unique", ["key"]);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:27:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9ghx8ClZDpNLa+tOy3rxtw


__PACKAGE__->meta->make_immutable;

1;
