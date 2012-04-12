use utf8;
package PomCur::TrackDB::PubCurationStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PomCur::TrackDB::PubCurationStatus

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<pub_curation_status>

=cut

__PACKAGE__->table("pub_curation_status");

=head1 ACCESSORS

=head2 pub_curation_status_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 annotation_type

  data_type: 'text'
  is_nullable: 1

=head2 status_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "pub_curation_status_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "annotation_type",
  { data_type => "text", is_nullable => 1 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</pub_curation_status_id>

=back

=cut

__PACKAGE__->set_primary_key("pub_curation_status_id");

=head1 RELATIONS

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

=head2 status

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "status",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "status_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07017 @ 2012-04-12 03:42:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5/HZrJ/xTr0VAsjxXaTyQg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
