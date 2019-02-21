use utf8;
package Canto::TrackDB::Strain;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::Strain

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<strain>

=cut

__PACKAGE__->table("strain");

=head1 ACCESSORS

=head2 strain_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 organism_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 strain_name

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "strain_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "organism_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "strain_name",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</strain_id>

=back

=cut

__PACKAGE__->set_primary_key("strain_id");

=head1 RELATIONS

=head2 organism

Type: belongs_to

Related object: L<Canto::TrackDB::Organism>

=cut

__PACKAGE__->belongs_to(
  "organism",
  "Canto::TrackDB::Organism",
  { organism_id => "organism_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-09-06 14:34:35
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:iamK8LIMUOWgK3jIqiBkKQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
