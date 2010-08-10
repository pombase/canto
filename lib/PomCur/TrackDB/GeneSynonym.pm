package PomCur::TrackDB::GeneSynonym;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("gene_synonym");
__PACKAGE__->add_columns(
  "gene_synonym_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "identifier",
  {
    data_type => "text",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "synonym_type",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("gene_synonym_id");
__PACKAGE__->belongs_to(
  "synonym_type",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "synonym_type" },
);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uX5YtUQM5/F72tVsOEC4ng


# You can replace this text with custom content, and it will be preserved on regeneration
1;
