package PomCur::TrackDB::PubStatus;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("pub_status");
__PACKAGE__->add_columns(
  "pub_status_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "pub_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "status",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "assigned_curator",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("pub_status_id");
__PACKAGE__->add_unique_constraint("pub_id_unique", ["pub_id"]);
__PACKAGE__->belongs_to("pub", "PomCur::TrackDB::Pub", { pub_id => "pub_id" });
__PACKAGE__->belongs_to("status", "PomCur::TrackDB::Cvterm", { cvterm_id => "status" });
__PACKAGE__->belongs_to(
  "assigned_curator",
  "PomCur::TrackDB::Person",
  { person_id => "assigned_curator" },
);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NpeyEGXXpTS0vcqbHabYqg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
