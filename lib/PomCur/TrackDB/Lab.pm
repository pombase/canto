package PomCur::TrackDB::Lab;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("lab");
__PACKAGE__->add_columns(
  "lab_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "lab_head",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "name",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("lab_id");
__PACKAGE__->has_many(
  "people",
  "PomCur::TrackDB::Person",
  { "foreign.lab" => "self.lab_id" },
);
__PACKAGE__->belongs_to(
  "lab_head",
  "PomCur::TrackDB::Person",
  { person_id => "lab_head" },
);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:q3VQo/Wgwdc6H6mVK5+Odw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
