package PomCur::TrackDB::Pub;

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
    is_nullable => 0,
    size => undef,
  },
  "title",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "authors",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("pub_id");
__PACKAGE__->has_many(
  "pubstatuses",
  "PomCur::TrackDB::Pubstatus",
  { "foreign.pub_id" => "self.pub_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-07-13 18:09:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FGzcEbXVGPafNdEAOHLdqw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
