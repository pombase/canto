package PomCur::TrackDB::Organism;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::TrackDB::Organism

=cut

__PACKAGE__->table("organism");

=head1 ACCESSORS

=head2 organism_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 abbreviation

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 genus

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 species

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 common_name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 comment

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "organism_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "abbreviation",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "genus",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "species",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "common_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "comment",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("organism_id");

=head1 RELATIONS

=head2 organismprops

Type: has_many

Related object: L<PomCur::TrackDB::Organismprop>

=cut

__PACKAGE__->has_many(
  "organismprops",
  "PomCur::TrackDB::Organismprop",
  { "foreign.organism_id" => "self.organism_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_organisms

Type: has_many

Related object: L<PomCur::TrackDB::PubOrganism>

=cut

__PACKAGE__->has_many(
  "pub_organisms",
  "PomCur::TrackDB::PubOrganism",
  { "foreign.organism" => "self.organism_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 genes

Type: has_many

Related object: L<PomCur::TrackDB::Gene>

=cut

__PACKAGE__->has_many(
  "genes",
  "PomCur::TrackDB::Gene",
  { "foreign.organism" => "self.organism_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-11-05 19:49:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:iMjS12EO7y/ChMNtsKugBQ

# the genus and species, used when displaying organisms
sub full_name {
  my $self = shift;

  return $self->genus() . ' ' . $self->species();
}

# You can replace this text with custom content, and it will be preserved on regeneration
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
