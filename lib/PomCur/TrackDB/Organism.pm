package PomCur::TrackDB::Organism;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("organism");
__PACKAGE__->add_columns(
  "organism_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "abbreviation",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 1,
    size => 255,
  },
  "genus",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 0,
    size => 255,
  },
  "species",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 0,
    size => 255,
  },
  "common_name",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 1,
    size => 255,
  },
  "comment",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("organism_id");
__PACKAGE__->has_many(
  "pub_organisms",
  "PomCur::TrackDB::PubOrganism",
  { "foreign.organism" => "self.organism_id" },
);
__PACKAGE__->has_many(
  "genes",
  "PomCur::TrackDB::Gene",
  { "foreign.organism" => "self.organism_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:alw3Rgi/i/SHvLABsMxHNA

# the genus and species, used when displaying organisms
sub full_name {
  my $self = shift;

  return $self->genus() . ' ' . $self->species();
}

# You can replace this text with custom content, and it will be preserved on regeneration
1;
