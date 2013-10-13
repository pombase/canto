use utf8;
package Canto::TrackDB::Lab;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::Lab

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<lab>

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

=head1 PRIMARY KEY

=over 4

=item * L</lab_id>

=back

=cut

__PACKAGE__->set_primary_key("lab_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<name_unique>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name_unique", ["name"]);

=head1 RELATIONS

=head2 lab_head

Type: belongs_to

Related object: L<Canto::TrackDB::Person>

=cut

__PACKAGE__->belongs_to(
  "lab_head",
  "Canto::TrackDB::Person",
  { person_id => "lab_head" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 people

Type: has_many

Related object: L<Canto::TrackDB::Person>

=cut

__PACKAGE__->has_many(
  "people",
  "Canto::TrackDB::Person",
  { "foreign.lab" => "self.lab_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:27:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mDXHvI7DgGeZICLRoY2Jig


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
