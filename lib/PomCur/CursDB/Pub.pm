package PomCur::CursDB::Pub;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("pub");
__PACKAGE__->add_columns(
  "pub_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "pubmedid",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "title",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "abstract",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "data",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("pub_id");
__PACKAGE__->add_unique_constraint("pubmedid_unique", ["pubmedid"]);
__PACKAGE__->has_many(
  "annotations",
  "PomCur::CursDB::Annotation",
  { "foreign.pub" => "self.pub_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hR59fGa8O8+3D1gqqB1oIA

use YAML;

__PACKAGE__->inflate_column('data', {
  inflate => sub { my @res = Load(shift); $res[0] },
  deflate => sub { Dump(shift) },
});

# You can replace this text with custom content, and it will be preserved on regeneration
1;
