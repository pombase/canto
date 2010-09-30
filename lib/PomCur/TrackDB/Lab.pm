package PomCur::TrackDB::Lab;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::TrackDB::Lab

=cut

__PACKAGE__->table("lab");

=head1 ACCESSORS

=head2 lab_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 lab_head

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "lab_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "lab_head",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("lab_id");

=head1 RELATIONS

=head2 people

Type: has_many

Related object: L<PomCur::TrackDB::Person>

=cut

__PACKAGE__->has_many(
  "people",
  "PomCur::TrackDB::Person",
  { "foreign.lab" => "self.lab_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 lab_head

Type: belongs_to

Related object: L<PomCur::TrackDB::Person>

=cut

__PACKAGE__->belongs_to(
  "lab_head",
  "PomCur::TrackDB::Person",
  { person_id => "lab_head" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-09-30 16:18:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AIvzZ2GZ3FZUL97QP9c7Tg


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
