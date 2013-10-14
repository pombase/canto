package Canto::ChadoDB::Featureprop;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::Featureprop

=head1 DESCRIPTION

A feature can have any number of slot-value property tags attached to it. This is an alternative to hardcoding a list of columns in the relational schema, and is completely extensible.

=cut

__PACKAGE__->table("featureprop");

=head1 ACCESSORS

=head2 featureprop_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'featureprop_featureprop_id_seq'

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. Certain property types will only apply to certain feature
types (e.g. the anticodon property will only apply to tRNA features) ;
the types here come from the sequence feature property ontology.

=head2 value

  data_type: 'text'
  is_nullable: 1

The value of the property, represented as text. Numeric values are converted to their text representation. This is less efficient than using native database types, but is easier to query.

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Property-Value ordering. Any
feature can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used

=cut

__PACKAGE__->add_columns(
  "featureprop_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "featureprop_featureprop_id_seq",
  },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 1 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("featureprop_id");
__PACKAGE__->add_unique_constraint("featureprop_c1", ["feature_id", "type_id", "rank"]);

=head1 RELATIONS

=head2 feature

Type: belongs_to

Related object: L<Canto::ChadoDB::Feature>

=cut

__PACKAGE__->belongs_to(
  "feature",
  "Canto::ChadoDB::Feature",
  { feature_id => "feature_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 type

Type: belongs_to

Related object: L<Canto::ChadoDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "Canto::ChadoDB::Cvterm",
  { cvterm_id => "type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 featureprop_pubs

Type: has_many

Related object: L<Canto::ChadoDB::FeaturepropPub>

=cut

__PACKAGE__->has_many(
  "featureprop_pubs",
  "Canto::ChadoDB::FeaturepropPub",
  { "foreign.featureprop_id" => "self.featureprop_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zfjrYHWiHM8Kk4pjIw3OXg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
