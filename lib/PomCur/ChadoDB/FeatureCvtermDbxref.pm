package PomCur::ChadoDB::FeatureCvtermDbxref;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::ChadoDB::FeatureCvtermDbxref

=head1 DESCRIPTION

Additional dbxrefs for an association. Rows in the feature_cvterm table may be backed up by dbxrefs. For example, a feature_cvterm association that was inferred via a protein-protein interaction may be backed by by refering to the dbxref for the alternate protein. Corresponds to the WITH column in a GO gene association file (but can also be used for other analagous associations). See http://www.geneontology.org/doc/GO.annotation.shtml#file for more details.

=cut

__PACKAGE__->table("feature_cvterm_dbxref");

=head1 ACCESSORS

=head2 feature_cvterm_dbxref_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq'

=head2 feature_cvterm_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 dbxref_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_cvterm_dbxref_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq",
  },
  "feature_cvterm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "dbxref_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("feature_cvterm_dbxref_id");
__PACKAGE__->add_unique_constraint(
  "feature_cvterm_dbxref_c1",
  ["feature_cvterm_id", "dbxref_id"],
);

=head1 RELATIONS

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

=head2 dbxref

Type: belongs_to

Related object: L<PomCur::ChadoDB::Dbxref>

=cut

__PACKAGE__->belongs_to(
  "dbxref",
  "PomCur::ChadoDB::Dbxref",
  { dbxref_id => "dbxref_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3ps5qp25+Xycp6j/4eazmw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
