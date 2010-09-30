package PomCur::CursDB::Metadata;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::CursDB::Metadata

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
__PACKAGE__->set_primary_key("metadata_id");
__PACKAGE__->add_unique_constraint("key_unique", ["key"]);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-09-30 16:18:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7sJTR/8hfCSh81OLzGe0fQ


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
