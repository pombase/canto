use utf8;
package Canto::TrackDB::PubOrganism;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::PubOrganism

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<pub_organism>

=cut

__PACKAGE__->table("pub_organism");

=head1 ACCESSORS

=head2 pub_organism_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 pub

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 organism

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "pub_organism_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "pub",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "organism",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</pub_organism_id>

=back

=cut

__PACKAGE__->set_primary_key("pub_organism_id");

=head1 RELATIONS

=head2 organism

Type: belongs_to

Related object: L<Canto::TrackDB::Organism>

=cut

__PACKAGE__->belongs_to(
  "organism",
  "Canto::TrackDB::Organism",
  { organism_id => "organism" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 pub

Type: belongs_to

Related object: L<Canto::TrackDB::Pub>

=cut

__PACKAGE__->belongs_to(
  "pub",
  "Canto::TrackDB::Pub",
  { pub_id => "pub" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:27:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HkrSH+9O6E8DcakztlBK4w


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
