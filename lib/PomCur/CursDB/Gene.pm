package PomCur::CursDB::Gene;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("gene");
__PACKAGE__->add_columns(
  "primary_id",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "systematic_identifier",
  {
    data_type => "test",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "primary_name",
  {
    data_type => "TEXT",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "gene_product",
  {
    data_type => "TEXT",
    default_value => undef,
    is_nullable => 1,
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
__PACKAGE__->set_primary_key("primary_id");
__PACKAGE__->add_unique_constraint("systematic_identifier_unique", ["systematic_identifier"]);
__PACKAGE__->belongs_to(
  "organism",
  "PomCur::CursDB::Organism",
  { organism_id => "organism" },
);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AqLOgRv1v2JIxQd3nyP0YQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
