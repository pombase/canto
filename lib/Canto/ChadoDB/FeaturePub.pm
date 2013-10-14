package Canto::ChadoDB::FeaturePub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::FeaturePub

=head1 DESCRIPTION

Provenance. Linking table between features and publications that mention them.

=cut

__PACKAGE__->table("feature_pub");

=head1 ACCESSORS

=head2 feature_pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_pub_feature_pub_id_seq'

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_pub_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_pub_feature_pub_id_seq",
  },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("feature_pub_id");
__PACKAGE__->add_unique_constraint("feature_pub_c1", ["feature_id", "pub_id"]);

=head1 RELATIONS

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

=head2 feature_pubprops

Type: has_many

Related object: L<Canto::ChadoDB::FeaturePubprop>

=cut

__PACKAGE__->has_many(
  "feature_pubprops",
  "Canto::ChadoDB::FeaturePubprop",
  { "foreign.feature_pub_id" => "self.feature_pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HpB9zKulTHFgxtNH7+9E6w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
