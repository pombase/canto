package Canto::ChadoDB::FeatureSynonym;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::FeatureSynonym - Linking table between feature and synonym.

=cut

__PACKAGE__->table("feature_synonym");

=head1 ACCESSORS

=head2 feature_synonym_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_synonym_feature_synonym_id_seq'

=head2 synonym_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The pub_id link is for relating the usage of a given synonym to the publication in which it was used.

=head2 is_current

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

The is_current boolean indicates whether the linked synonym is the  current -official- symbol for the linked feature.

=head2 is_internal

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

Typically a synonym exists so that somebody querying the db with an obsolete name can find the object theyre looking for (under its current name.  If the synonym has been used publicly and deliberately (e.g. in a paper), it may also be listed in reports as a synonym. If the synonym was not used deliberately (e.g. there was a typo which went public), then the is_internal boolean may be set to -true- so that it is known that the synonym is -internal- and should be queryable but should not be listed in reports as a valid synonym.

=cut

__PACKAGE__->add_columns(
  "feature_synonym_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_synonym_feature_synonym_id_seq",
  },
  "synonym_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_current",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_internal",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("feature_synonym_id");
__PACKAGE__->add_unique_constraint("feature_synonym_c1", ["synonym_id", "feature_id", "pub_id"]);

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

=head2 pub

Type: belongs_to

Related object: L<Canto::ChadoDB::Pub>

=cut

__PACKAGE__->belongs_to(
  "pub",
  "Canto::ChadoDB::Pub",
  { pub_id => "pub_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 synonym

Type: belongs_to

Related object: L<Canto::ChadoDB::Synonym>

=cut

__PACKAGE__->belongs_to(
  "synonym",
  "Canto::ChadoDB::Synonym",
  { synonym_id => "synonym_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:f1snMBMCGD2xK2qvyi+FfA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
