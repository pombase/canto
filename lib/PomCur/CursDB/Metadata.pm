package PomCur::CursDB::Metadata;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("metadata");
__PACKAGE__->add_columns(
  "metadata_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "key",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "value",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("metadata_id");
__PACKAGE__->add_unique_constraint("key_unique", ["key"]);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:a3BvrsCqNKpjf1q/5t3KLg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
