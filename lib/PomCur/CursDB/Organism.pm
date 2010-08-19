package PomCur::CursDB::Organism;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("organism");
__PACKAGE__->add_columns(
  "organism_id",
  {
    data_type => "integer",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "full_name",
  {
    data_type => "TEXT",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("organism_id");
__PACKAGE__->add_unique_constraint("full_name_unique", ["full_name"]);
__PACKAGE__->has_many(
  "genes",
  "PomCur::CursDB::Gene",
  { "foreign.organism" => "self.organism_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HwKZ0N4+QGF+6XR4JPk0Vw

sub get_organism
{
  my $schema = shift;
  my $name = shift;

  my $organism =
    $schema->resultset('Organism')->search({ full_name => $name })->first();

  if (!defined $organism) {
    $organism = $schema->create_with_type('Organism', { full_name => $name });
  }

  return $organism;
}

1;
