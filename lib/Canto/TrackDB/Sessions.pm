use utf8;
package Canto::TrackDB::Sessions;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::Sessions

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<sessions>

=cut

__PACKAGE__->table("sessions");

=head1 ACCESSORS

=head2 id

  data_type: 'text'
  is_nullable: 0

=head2 session_data

  data_type: 'text'
  is_nullable: 1

=head2 expires

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "text", is_nullable => 0 },
  "session_data",
  { data_type => "text", is_nullable => 1 },
  "expires",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:27:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Zfzd/kiKJJWHXY6n0xZfcQ


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
