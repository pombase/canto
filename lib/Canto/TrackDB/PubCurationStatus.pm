use utf8;
package Canto::TrackDB::PubCurationStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::PubCurationStatus

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

Related object: L<Canto::TrackDB::Pub>

=cut

__PACKAGE__->belongs_to(
  "pub",
  "Canto::TrackDB::Pub",
  { pub_id => "pub_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 status

Type: belongs_to

Related object: L<Canto::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "status",
  "Canto::TrackDB::Cvterm",
  { cvterm_id => "status_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-08-21 19:47:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hQBFv8gIwqpII+84HfkyCQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
