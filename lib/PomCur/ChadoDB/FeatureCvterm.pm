package PomCur::ChadoDB::FeatureCvterm;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::ChadoDB::FeatureCvterm

=head1 DESCRIPTION

Associate a term from a cv with a feature, for example, GO annotation.

=cut

__PACKAGE__->table("feature_cvterm");

=head1 ACCESSORS

=head2 feature_cvterm_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_cvterm_feature_cvterm_id_seq'

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 cvterm_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Provenance for the annotation. Each annotation should have a single primary publication (which may be of the appropriate type for computational analyses) where more details can be found. Additional provenance dbxrefs can be attached using feature_cvterm_dbxref.

=head2 is_not

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

If this is set to true, then this annotation is interpreted as a NEGATIVE annotation - i.e. the feature does NOT have the specified function, process, component, part, etc. See GO docs for more details.

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_cvterm_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_cvterm_feature_cvterm_id_seq",
  },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "cvterm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_not",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("feature_cvterm_id");
__PACKAGE__->add_unique_constraint(
  "feature_cvterm_c1",
  ["feature_id", "cvterm_id", "pub_id", "rank"],
);

=head1 RELATIONS

=head2 feature

Type: belongs_to

Related object: L<PomCur::ChadoDB::Feature>

=cut

__PACKAGE__->belongs_to(
  "feature",
  "PomCur::ChadoDB::Feature",
  { feature_id => "feature_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 pub

Type: belongs_to

Related object: L<PomCur::ChadoDB::Pub>

=cut

__PACKAGE__->belongs_to(
  "pub",
  "PomCur::ChadoDB::Pub",
  { pub_id => "pub_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 cvterm

Type: belongs_to

Related object: L<PomCur::ChadoDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "cvterm",
  "PomCur::ChadoDB::Cvterm",
  { cvterm_id => "cvterm_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 feature_cvterm_dbxrefs

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureCvtermDbxref>

=cut

__PACKAGE__->has_many(
  "feature_cvterm_dbxrefs",
  "PomCur::ChadoDB::FeatureCvtermDbxref",
  { "foreign.feature_cvterm_id" => "self.feature_cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvtermprops

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureCvtermprop>

=cut

__PACKAGE__->has_many(
  "feature_cvtermprops",
  "PomCur::ChadoDB::FeatureCvtermprop",
  { "foreign.feature_cvterm_id" => "self.feature_cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvterm_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureCvtermPub>

=cut

__PACKAGE__->has_many(
  "feature_cvterm_pubs",
  "PomCur::ChadoDB::FeatureCvtermPub",
  { "foreign.feature_cvterm_id" => "self.feature_cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ylDyrDCA9ZESZDf2NOxv/w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
