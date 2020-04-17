use utf8;
package Canto::TrackDB::Strainsynonym;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::Strainsynonym

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<strainsynonym>

=cut

__PACKAGE__->table("strainsynonym");

=head1 ACCESSORS

=head2 strainsynonym_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 strain_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 synonym

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "strainsynonym_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "strain_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "synonym",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</strainsynonym_id>

=back

=cut

__PACKAGE__->set_primary_key("strainsynonym_id");

=head1 RELATIONS

=head2 strain

Type: belongs_to

Related object: L<Canto::TrackDB::Strain>

=cut

__PACKAGE__->belongs_to(
  "strain",
  "Canto::TrackDB::Strain",
  { strain_id => "strain_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2020-02-24 22:11:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:XWh0jUe3t7dytsMLNNmH7A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
