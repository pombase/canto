use utf8;
package Canto::TrackDB::Cvtermprop;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::Cvtermprop

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<cvtermprop>

=cut

__PACKAGE__->table("cvtermprop");

=head1 ACCESSORS

=head2 cvtermprop_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 cvterm_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 value

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "cvtermprop_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "cvterm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</cvtermprop_id>

=back

=cut

__PACKAGE__->set_primary_key("cvtermprop_id");

=head1 RELATIONS

=head2 cvterm

Type: belongs_to

Related object: L<Canto::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "cvterm",
  "Canto::TrackDB::Cvterm",
  { cvterm_id => "cvterm_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 type

Type: belongs_to

Related object: L<Canto::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "Canto::TrackDB::Cvterm",
  { cvterm_id => "type_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:27:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qjN3DwLciVEzyTQL9c6e9w


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
