package PomCur::TrackDB::Person;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::TrackDB::Person

=cut

__PACKAGE__->table("person");

=head1 ACCESSORS

=head2 person_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 email_address

  data_type: 'text'
  is_nullable: 0

=head2 role

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 lab

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 session_data

  data_type: 'text'
  is_nullable: 1

=head2 password

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "person_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "email_address",
  { data_type => "text", is_nullable => 0 },
  "role",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "lab",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "session_data",
  { data_type => "text", is_nullable => 1 },
  "password",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("person_id");
__PACKAGE__->add_unique_constraint("email_address_unique", ["email_address"]);

=head1 RELATIONS

=head2 pubs

Type: has_many

Related object: L<PomCur::TrackDB::Pub>

=cut

__PACKAGE__->has_many(
  "pubs",
  "PomCur::TrackDB::Pub",
  { "foreign.assigned_curator" => "self.person_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 lab

Type: belongs_to

Related object: L<PomCur::TrackDB::Lab>

=cut

__PACKAGE__->belongs_to(
  "lab",
  "PomCur::TrackDB::Lab",
  { lab_id => "lab" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 role

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "role",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "role" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 curs

Type: has_many

Related object: L<PomCur::TrackDB::Curs>

=cut

__PACKAGE__->has_many(
  "curs",
  "PomCur::TrackDB::Curs",
  { "foreign.curator" => "self.person_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 labs

Type: has_many

Related object: L<PomCur::TrackDB::Lab>

=cut

__PACKAGE__->has_many(
  "labs",
  "PomCur::TrackDB::Lab",
  { "foreign.lab_head" => "self.person_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-03-23 13:36:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:70J2cJgsRTqxqflFlB6qaQ

__PACKAGE__->meta->make_immutable;
1;
