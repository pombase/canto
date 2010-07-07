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
    is_nullable => 0,
    size => undef,
  },
  "status",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "pub_id",
  {
    data_type => "integer",
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
__PACKAGE__->set_primary_key("annotation_id", "status");
__PACKAGE__->belongs_to("pub", "PomCur::CursDB::Pub", { pub_id => "pub_id" });


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:d0te2s/L0vWLIClrT9medQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
