package PomCur::TrackDB::Pubstatus;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("pubstatus");
__PACKAGE__->add_columns(
  "pubstatus_id",
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
);
__PACKAGE__->set_primary_key("pubstatus_id");
__PACKAGE__->belongs_to("pub", "PomCur::TrackDB::Pub", { pub_id => "pub_id" });
__PACKAGE__->belongs_to("status", "PomCur::TrackDB::Cvterm", { cvterm_id => "status" });


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-07-13 18:09:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:T6PHEINBy+3DY0YpdKdgQA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
