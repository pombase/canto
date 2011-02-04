package PomCur::ChadoDB::FeatureCvtermprop;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::ChadoDB::FeatureCvtermprop

=head1 DESCRIPTION

Extensible properties for
feature to cvterm associations. Examples: GO evidence codes;
qualifiers; metadata such as the date on which the entry was curated
and the source of the association. See the featureprop table for
meanings of type_id, value and rank.

=cut

__PACKAGE__->table("feature_cvtermprop");

=head1 ACCESSORS

=head2 feature_cvtermprop_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_cvtermprop_feature_cvtermprop_id_seq'

=head2 feature_cvterm_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. cvterms may come from the OBO evidence code cv.

=head2 value

  data_type: 'text'
  is_nullable: 1

The value of the
property, represented as text. Numeric values are converted to their
text representation. This is less efficient than using native database
types, but is easier to query.

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Property-Value
ordering. Any feature_cvterm can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used.

=cut

__PACKAGE__->add_columns(
  "feature_cvtermprop_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_cvtermprop_feature_cvtermprop_id_seq",
  },
  "feature_cvterm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 1 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("feature_cvtermprop_id");
__PACKAGE__->add_unique_constraint(
  "feature_cvtermprop_c1",
  ["feature_cvterm_id", "type_id", "rank"],
);

=head1 RELATIONS

=head2 type

Type: belongs_to

Related object: L<PomCur::ChadoDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "PomCur::ChadoDB::Cvterm",
  { cvterm_id => "type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 feature_cvterm

Type: belongs_to

Related object: L<PomCur::ChadoDB::FeatureCvterm>

=cut

__PACKAGE__->belongs_to(
  "feature_cvterm",
  "PomCur::ChadoDB::FeatureCvterm",
  { feature_cvterm_id => "feature_cvterm_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:eikxV0FaYlokUgoZKcD69w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
