package PomCur::TrackDB::PubOrganism;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("pub_organism");
__PACKAGE__->add_columns(
  "pub_organism_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "pub",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "organism",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("pub_organism_id");
__PACKAGE__->belongs_to("pub", "PomCur::TrackDB::Pub", { pub_id => "pub" });
__PACKAGE__->belongs_to(
  "organism",
  "PomCur::TrackDB::Organism",
  { organism_id => "organism" },
);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SEupkw4EAorXE+WuZgXoMw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
