package PomCur::TrackDB::Curs;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("curs");
__PACKAGE__->add_columns(
  "curs_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "community_curator",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("curs_id");
__PACKAGE__->belongs_to(
  "community_curator",
  "PomCur::TrackDB::Person",
  { person_id => "community_curator" },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-07-13 18:09:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5EI/AZt3E0dsQ5BDAITIyw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
