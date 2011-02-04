package PomCur::ChadoDB::FeatureRelationshippropPub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::ChadoDB::FeatureRelationshippropPub - Provenance for feature_relationshipprop.

=cut

__PACKAGE__->table("feature_relationshipprop_pub");

=head1 ACCESSORS

=head2 feature_relationshipprop_pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq'

=head2 feature_relationshipprop_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_relationshipprop_pub_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq",
  },
  "feature_relationshipprop_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("feature_relationshipprop_pub_id");
__PACKAGE__->add_unique_constraint(
  "feature_relationshipprop_pub_c1",
  ["feature_relationshipprop_id", "pub_id"],
);

=head1 RELATIONS

=head2 feature_relationshipprop

Type: belongs_to

Related object: L<PomCur::ChadoDB::FeatureRelationshipprop>

=cut

__PACKAGE__->belongs_to(
  "feature_relationshipprop",
  "PomCur::ChadoDB::FeatureRelationshipprop",
  { feature_relationshipprop_id => "feature_relationshipprop_id" },
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


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/bkB2cLPx7G6ebS4ODaTrA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
