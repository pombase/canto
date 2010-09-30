package PomCur::TrackDB::PubStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::TrackDB::PubStatus

=cut

__PACKAGE__->table("pub_status");

=head1 ACCESSORS

=head2 pub_status_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 status

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 assigned_curator

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "pub_status_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "status",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "assigned_curator",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("pub_status_id");
__PACKAGE__->add_unique_constraint("pub_id_unique", ["pub_id"]);

=head1 RELATIONS

=head2 assigned_curator

Type: belongs_to

Related object: L<PomCur::TrackDB::Person>

=cut

__PACKAGE__->belongs_to(
  "assigned_curator",
  "PomCur::TrackDB::Person",
  { person_id => "assigned_curator" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 status

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "status",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "status" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 pub

Type: belongs_to

Related object: L<PomCur::TrackDB::Pub>

=cut

__PACKAGE__->belongs_to(
  "pub",
  "PomCur::TrackDB::Pub",
  { pub_id => "pub_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-09-30 16:18:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Pfid9aHZIkaVkFVpj7zPYw


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
