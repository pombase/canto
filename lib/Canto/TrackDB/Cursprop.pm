use utf8;
package Canto::TrackDB::Cursprop;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::Cursprop

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<cursprop>

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

=head1 PRIMARY KEY

=over 4

=item * L</cursprop_id>

=back

=cut

__PACKAGE__->set_primary_key("cursprop_id");

=head1 RELATIONS

=head2 curs

Type: belongs_to

Related object: L<Canto::TrackDB::Curs>

=cut

__PACKAGE__->belongs_to(
  "curs",
  "Canto::TrackDB::Curs",
  { curs_id => "curs" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 type

Type: belongs_to

Related object: L<Canto::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "Canto::TrackDB::Cvterm",
  { cvterm_id => "type" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:27:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gGCZIdxc68+DPOXFR4MhVw

__PACKAGE__->belongs_to(
  "curs",
  "Canto::TrackDB::Curs",
  { curs_id => "curs" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
