package PomCur::TrackDB::Cursprop;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::TrackDB::Cursprop

=cut

__PACKAGE__->table("cursprop");

=head1 ACCESSORS

=head2 cursprop_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 curs

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 type

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 value

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "cursprop_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "curs",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("cursprop_id");

=head1 RELATIONS

=head2 type

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "type" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 cur

Type: belongs_to

Related object: L<PomCur::TrackDB::Curs>

=cut

__PACKAGE__->belongs_to(
  "cur",
  "PomCur::TrackDB::Curs",
  { curs_id => "curs" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-01-18 06:44:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:argmwbDRClSHIAg9kY/yzw


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
