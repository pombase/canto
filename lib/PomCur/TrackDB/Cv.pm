package PomCur::TrackDB::Cv;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("cv");
__PACKAGE__->add_columns(
  "cv_id",
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
  "definition",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("cv_id");
__PACKAGE__->has_many(
  "cvterms",
  "PomCur::TrackDB::Cvterm",
  { "foreign.cv_id" => "self.cv_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IQrMXtwseoBQc7U8kV7JHQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
