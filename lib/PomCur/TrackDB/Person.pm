package PomCur::TrackDB::Person;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("person");
__PACKAGE__->add_columns(
  "person_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "shortname",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "longname",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "networkaddress",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "role",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "lab",
  {
    data_type => "INTEGER",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "session_data",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "password",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("person_id");
__PACKAGE__->add_unique_constraint("networkaddress_unique", ["networkaddress"]);
__PACKAGE__->belongs_to("lab", "PomCur::TrackDB::Lab", { lab_id => "lab" });
__PACKAGE__->has_many(
  "curs",
  "PomCur::TrackDB::Curs",
  { "foreign.community_curator" => "self.person_id" },
);
__PACKAGE__->has_many(
  "labs",
  "PomCur::TrackDB::Lab",
  { "foreign.lab_head" => "self.person_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EIOdRrZtPgK2sd1yL42Fcg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
