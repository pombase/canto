package PomCur::CursDB::Organism;

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
    is_nullable => 1,
    size => undef,
  },
  "name",
  {
    data_type => "TEXT",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "ncbi_taxonomy_identifier",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("organism_id");
__PACKAGE__->add_unique_constraint("name_unique", ["name"]);
__PACKAGE__->has_many(
  "genes",
  "PomCur::CursDB::Gene",
  { "foreign.organism" => "self.organism_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:C655jt8udLWm9E1TWD3RVA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
