package PomCur::ChadoDB::Pub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::ChadoDB::Pub

=head1 DESCRIPTION

A documented provenance artefact - publications,
documents, personal communication.

=cut

__PACKAGE__->table("pub");

=head1 ACCESSORS

=head2 pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'pub_pub_id_seq'

=head2 title

  data_type: 'text'
  is_nullable: 1

Descriptive general heading.

=head2 volumetitle

  data_type: 'text'
  is_nullable: 1

Title of part if one of a series.

=head2 volume

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 series_name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

Full name of (journal) series.

=head2 issue

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 pyear

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 pages

  data_type: 'varchar'
  is_nullable: 1
  size: 255

Page number range[s], e.g. 457--459, viii + 664pp, lv--lvii.

=head2 miniref

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 uniquename

  data_type: 'text'
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The type of the publication (book, journal, poem, graffiti, etc). Uses pub cv.

=head2 is_obsolete

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 publisher

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 pubplace

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "pub_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "pub_pub_id_seq",
  },
  "title",
  { data_type => "text", is_nullable => 1 },
  "volumetitle",
  { data_type => "text", is_nullable => 1 },
  "volume",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "series_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "issue",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "pyear",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "pages",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "miniref",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "uniquename",
  { data_type => "text", is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_obsolete",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "publisher",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "pubplace",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("pub_id");
__PACKAGE__->add_unique_constraint("pub_c1", ["uniquename"]);

=head1 RELATIONS

=head2 cell_line_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::CellLineCvterm>

=cut

__PACKAGE__->has_many(
  "cell_line_cvterms",
  "PomCur::ChadoDB::CellLineCvterm",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_features

Type: has_many

Related object: L<PomCur::ChadoDB::CellLineFeature>

=cut

__PACKAGE__->has_many(
  "cell_line_features",
  "PomCur::ChadoDB::CellLineFeature",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_libraries

Type: has_many

Related object: L<PomCur::ChadoDB::CellLineLibrary>

=cut

__PACKAGE__->has_many(
  "cell_line_libraries",
  "PomCur::ChadoDB::CellLineLibrary",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_lineprop_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::CellLinepropPub>

=cut

__PACKAGE__->has_many(
  "cell_lineprop_pubs",
  "PomCur::ChadoDB::CellLinepropPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::CellLinePub>

=cut

__PACKAGE__->has_many(
  "cell_line_pubs",
  "PomCur::ChadoDB::CellLinePub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_synonyms

Type: has_many

Related object: L<PomCur::ChadoDB::CellLineSynonym>

=cut

__PACKAGE__->has_many(
  "cell_line_synonyms",
  "PomCur::ChadoDB::CellLineSynonym",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 expression_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::ExpressionPub>

=cut

__PACKAGE__->has_many(
  "expression_pubs",
  "PomCur::ChadoDB::ExpressionPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureCvterm>

=cut

__PACKAGE__->has_many(
  "feature_cvterms",
  "PomCur::ChadoDB::FeatureCvterm",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvterm_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureCvtermPub>

=cut

__PACKAGE__->has_many(
  "feature_cvterm_pubs",
  "PomCur::ChadoDB::FeatureCvtermPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_expressions

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureExpression>

=cut

__PACKAGE__->has_many(
  "feature_expressions",
  "PomCur::ChadoDB::FeatureExpression",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureloc_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::FeaturelocPub>

=cut

__PACKAGE__->has_many(
  "featureloc_pubs",
  "PomCur::ChadoDB::FeaturelocPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featuremap_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::FeaturemapPub>

=cut

__PACKAGE__->has_many(
  "featuremap_pubs",
  "PomCur::ChadoDB::FeaturemapPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureprop_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::FeaturepropPub>

=cut

__PACKAGE__->has_many(
  "featureprop_pubs",
  "PomCur::ChadoDB::FeaturepropPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::FeaturePub>

=cut

__PACKAGE__->has_many(
  "feature_pubs",
  "PomCur::ChadoDB::FeaturePub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationshipprop_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureRelationshippropPub>

=cut

__PACKAGE__->has_many(
  "feature_relationshipprop_pubs",
  "PomCur::ChadoDB::FeatureRelationshippropPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationship_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureRelationshipPub>

=cut

__PACKAGE__->has_many(
  "feature_relationship_pubs",
  "PomCur::ChadoDB::FeatureRelationshipPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_synonyms

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureSynonym>

=cut

__PACKAGE__->has_many(
  "feature_synonyms",
  "PomCur::ChadoDB::FeatureSynonym",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 library_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::LibraryCvterm>

=cut

__PACKAGE__->has_many(
  "library_cvterms",
  "PomCur::ChadoDB::LibraryCvterm",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 libraryprop_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::LibrarypropPub>

=cut

__PACKAGE__->has_many(
  "libraryprop_pubs",
  "PomCur::ChadoDB::LibrarypropPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 library_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::LibraryPub>

=cut

__PACKAGE__->has_many(
  "library_pubs",
  "PomCur::ChadoDB::LibraryPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 library_synonyms

Type: has_many

Related object: L<PomCur::ChadoDB::LibrarySynonym>

=cut

__PACKAGE__->has_many(
  "library_synonyms",
  "PomCur::ChadoDB::LibrarySynonym",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_experiment_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::NdExperimentPub>

=cut

__PACKAGE__->has_many(
  "nd_experiment_pubs",
  "PomCur::ChadoDB::NdExperimentPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phendescs

Type: has_many

Related object: L<PomCur::ChadoDB::Phendesc>

=cut

__PACKAGE__->has_many(
  "phendescs",
  "PomCur::ChadoDB::Phendesc",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_comparisons

Type: has_many

Related object: L<PomCur::ChadoDB::PhenotypeComparison>

=cut

__PACKAGE__->has_many(
  "phenotype_comparisons",
  "PomCur::ChadoDB::PhenotypeComparison",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_comparison_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::PhenotypeComparisonCvterm>

=cut

__PACKAGE__->has_many(
  "phenotype_comparison_cvterms",
  "PomCur::ChadoDB::PhenotypeComparisonCvterm",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenstatements

Type: has_many

Related object: L<PomCur::ChadoDB::Phenstatement>

=cut

__PACKAGE__->has_many(
  "phenstatements",
  "PomCur::ChadoDB::Phenstatement",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylonode_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::PhylonodePub>

=cut

__PACKAGE__->has_many(
  "phylonode_pubs",
  "PomCur::ChadoDB::PhylonodePub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylotree_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::PhylotreePub>

=cut

__PACKAGE__->has_many(
  "phylotree_pubs",
  "PomCur::ChadoDB::PhylotreePub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 project_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::ProjectPub>

=cut

__PACKAGE__->has_many(
  "project_pubs",
  "PomCur::ChadoDB::ProjectPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 protocols

Type: has_many

Related object: L<PomCur::ChadoDB::Protocol>

=cut

__PACKAGE__->has_many(
  "protocols",
  "PomCur::ChadoDB::Protocol",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

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

=head2 pubauthors

Type: has_many

Related object: L<PomCur::ChadoDB::Pubauthor>

=cut

__PACKAGE__->has_many(
  "pubauthors",
  "PomCur::ChadoDB::Pubauthor",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_dbxrefs

Type: has_many

Related object: L<PomCur::ChadoDB::PubDbxref>

=cut

__PACKAGE__->has_many(
  "pub_dbxrefs",
  "PomCur::ChadoDB::PubDbxref",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubprops

Type: has_many

Related object: L<PomCur::ChadoDB::Pubprop>

=cut

__PACKAGE__->has_many(
  "pubprops",
  "PomCur::ChadoDB::Pubprop",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_relationship_objects

Type: has_many

Related object: L<PomCur::ChadoDB::PubRelationship>

=cut

__PACKAGE__->has_many(
  "pub_relationship_objects",
  "PomCur::ChadoDB::PubRelationship",
  { "foreign.object_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_relationship_subjects

Type: has_many

Related object: L<PomCur::ChadoDB::PubRelationship>

=cut

__PACKAGE__->has_many(
  "pub_relationship_subjects",
  "PomCur::ChadoDB::PubRelationship",
  { "foreign.subject_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::StockCvterm>

=cut

__PACKAGE__->has_many(
  "stock_cvterms",
  "PomCur::ChadoDB::StockCvterm",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stockprop_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::StockpropPub>

=cut

__PACKAGE__->has_many(
  "stockprop_pubs",
  "PomCur::ChadoDB::StockpropPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::StockPub>

=cut

__PACKAGE__->has_many(
  "stock_pubs",
  "PomCur::ChadoDB::StockPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_relationship_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::StockRelationshipCvterm>

=cut

__PACKAGE__->has_many(
  "stock_relationship_cvterms",
  "PomCur::ChadoDB::StockRelationshipCvterm",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_relationship_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::StockRelationshipPub>

=cut

__PACKAGE__->has_many(
  "stock_relationship_pubs",
  "PomCur::ChadoDB::StockRelationshipPub",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 studies

Type: has_many

Related object: L<PomCur::ChadoDB::Study>

=cut

__PACKAGE__->has_many(
  "studies",
  "PomCur::ChadoDB::Study",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bIZV/XS+tggpuOBVLqVoGw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
