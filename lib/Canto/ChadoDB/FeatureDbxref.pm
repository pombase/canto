package Canto::ChadoDB::FeatureDbxref;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::FeatureDbxref

=head1 DESCRIPTION

Links a feature to dbxrefs. This is for secondary identifiers; primary identifiers should use feature.dbxref_id.

=cut

__PACKAGE__->table("feature_dbxref");

=head1 ACCESSORS

=head2 feature_dbxref_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_dbxref_feature_dbxref_id_seq'

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 dbxref_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 is_current

  data_type: 'boolean'
  default_value: true
  is_nullable: 0

True if this secondary dbxref is the most up to date accession in the corresponding db. Retired accessions should set this field to false

=cut

__PACKAGE__->add_columns(
  "feature_dbxref_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_dbxref_feature_dbxref_id_seq",
  },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "dbxref_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_current",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("feature_dbxref_id");
__PACKAGE__->add_unique_constraint("feature_dbxref_c1", ["feature_id", "dbxref_id"]);

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

=head2 dbxref

Type: belongs_to

Related object: L<Canto::ChadoDB::Dbxref>

=cut

__PACKAGE__->belongs_to(
  "dbxref",
  "Canto::ChadoDB::Dbxref",
  { dbxref_id => "dbxref_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yYF38BBZAZGz4srhVK5ZYQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
