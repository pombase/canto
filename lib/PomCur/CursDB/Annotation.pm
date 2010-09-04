package PomCur::CursDB::Annotation;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("annotation");
__PACKAGE__->add_columns(
  "annotation_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "status",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "pub",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "type",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
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
__PACKAGE__->set_primary_key("annotation_id");
__PACKAGE__->add_unique_constraint(
  "annotation_id_status_type_unique",
  ["annotation_id", "status", "type"],
);
__PACKAGE__->belongs_to("pub", "PomCur::CursDB::Pub", { pub_id => "pub" });


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:w3NhVm4J4B4Vs8fIFmfI5g

use YAML;

__PACKAGE__->inflate_column('data', {
  inflate => sub { my @res = Load(shift); $res[0] },
  deflate => sub { Dump(shift) },
});


# You can replace this text with custom content, and it will be preserved on regeneration
1;
