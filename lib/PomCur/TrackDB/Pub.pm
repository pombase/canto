package PomCur::TrackDB::Pub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::TrackDB::Pub

=cut

__PACKAGE__->table("pub");

=head1 ACCESSORS

=head2 pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 uniquename

  data_type: 'text'
  is_nullable: 1

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 community_curator

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 title

  data_type: 'text'
  is_nullable: 1

=head2 abstract

  data_type: 'text'
  is_nullable: 1

=head2 authors

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "pub_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "uniquename",
  { data_type => "text", is_nullable => 1 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "community_curator",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "abstract",
  { data_type => "text", is_nullable => 1 },
  "authors",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("pub_id");
__PACKAGE__->add_unique_constraint("uniquename_unique", ["uniquename"]);

=head1 RELATIONS

=head2 community_curator

Type: belongs_to

Related object: L<PomCur::TrackDB::Person>

=cut

__PACKAGE__->belongs_to(
  "community_curator",
  "PomCur::TrackDB::Person",
  { person_id => "community_curator" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 type

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 pub_organisms

Type: has_many

Related object: L<PomCur::TrackDB::PubOrganism>

=cut

__PACKAGE__->has_many(
  "pub_organisms",
  "PomCur::TrackDB::PubOrganism",
  { "foreign.pub" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_status

Type: might_have

Related object: L<PomCur::TrackDB::PubStatus>

=cut

__PACKAGE__->might_have(
  "pub_status",
  "PomCur::TrackDB::PubStatus",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 curs

Type: has_many

Related object: L<PomCur::TrackDB::Curs>

=cut

__PACKAGE__->has_many(
  "curs",
  "PomCur::TrackDB::Curs",
  { "foreign.pub" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-03-08 14:40:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1IAGYK4wHcp38xAqNsx27g


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
