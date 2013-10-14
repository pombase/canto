package Canto::ChadoDB::FeatureRelationship;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::FeatureRelationship

=head1 DESCRIPTION

Features can be arranged in
graphs, e.g. "exon part_of transcript part_of gene"; If type is
thought of as a verb, the each arc or edge makes a statement
[Subject Verb Object]. The object can also be thought of as parent
(containing feature), and subject as child (contained feature or
subfeature). We include the relationship rank/order, because even
though most of the time we can order things implicitly by sequence
coordinates, we can not always do this - e.g. transpliced genes. It is also
useful for quickly getting implicit introns.

=cut

__PACKAGE__->table("feature_relationship");

=head1 ACCESSORS

=head2 feature_relationship_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_relationship_feature_relationship_id_seq'

=head2 subject_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The subject of the subj-predicate-obj sentence. This is typically the subfeature.

=head2 object_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The object of the subj-predicate-obj sentence. This is typically the container feature.

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Relationship type between subject and object. This is a cvterm, typically from the OBO relationship ontology, although other relationship types are allowed. The most common relationship type is OBO_REL:part_of. Valid relationship types are constrained by the Sequence Ontology.

=head2 value

  data_type: 'text'
  is_nullable: 1

Additional notes or comments.

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

The ordering of subject features with respect to the object feature may be important (for example, exon ordering on a transcript - not always derivable if you take trans spliced genes into consideration). Rank is used to order these; starts from zero.

=cut

__PACKAGE__->add_columns(
  "feature_relationship_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_relationship_feature_relationship_id_seq",
  },
  "subject_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "object_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 1 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("feature_relationship_id");
__PACKAGE__->add_unique_constraint(
  "feature_relationship_c1",
  ["subject_id", "object_id", "type_id", "rank"],
);

=head1 RELATIONS

=head2 subject

Type: belongs_to

Related object: L<Canto::ChadoDB::Feature>

=cut

__PACKAGE__->belongs_to(
  "subject",
  "Canto::ChadoDB::Feature",
  { feature_id => "subject_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 object

Type: belongs_to

Related object: L<Canto::ChadoDB::Feature>

=cut

__PACKAGE__->belongs_to(
  "object",
  "Canto::ChadoDB::Feature",
  { feature_id => "object_id" },
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

=head2 feature_relationshipprops

Type: has_many

Related object: L<Canto::ChadoDB::FeatureRelationshipprop>

=cut

__PACKAGE__->has_many(
  "feature_relationshipprops",
  "Canto::ChadoDB::FeatureRelationshipprop",
  {
    "foreign.feature_relationship_id" => "self.feature_relationship_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationship_pubs

Type: has_many

Related object: L<Canto::ChadoDB::FeatureRelationshipPub>

=cut

__PACKAGE__->has_many(
  "feature_relationship_pubs",
  "Canto::ChadoDB::FeatureRelationshipPub",
  {
    "foreign.feature_relationship_id" => "self.feature_relationship_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5hIquYQhkxAHNkIlA2b4LQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
