package PomCur::ChadoDB::Cvterm;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::ChadoDB::Cvterm

=head1 DESCRIPTION

A term, class, universal or type within an
ontology or controlled vocabulary.  This table is also used for
relations and properties. cvterms constitute nodes in the graph
defined by the collection of cvterms and cvterm_relationships.

=cut

__PACKAGE__->table("cvterm");

=head1 ACCESSORS

=head2 cvterm_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'cvterm_cvterm_id_seq'

=head2 cv_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The cv or ontology or namespace to which
this cvterm belongs.

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 1024

A concise human-readable name or
label for the cvterm. Uniquely identifies a cvterm within a cv.

=head2 definition

  data_type: 'text'
  is_nullable: 1

A human-readable text
definition.

=head2 dbxref_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Primary identifier dbxref - The
unique global OBO identifier for this cvterm.  Note that a cvterm may
have multiple secondary dbxrefs - see also table: cvterm_dbxref.

=head2 is_obsolete

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Boolean 0=false,1=true; see
GO documentation for details of obsoletion. Note that two terms with
different primary dbxrefs may exist if one is obsolete.

=head2 is_relationshiptype

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Boolean
0=false,1=true relations or relationship types (also known as Typedefs
in OBO format, or as properties or slots) form a cv/ontology in
themselves. We use this flag to indicate whether this cvterm is an
actual term/class/universal or a relation. Relations may be drawn from
the OBO Relations ontology, but are not exclusively drawn from there.

=cut

__PACKAGE__->add_columns(
  "cvterm_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "cvterm_cvterm_id_seq",
  },
  "cv_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 1024 },
  "definition",
  { data_type => "text", is_nullable => 1 },
  "dbxref_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_obsolete",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "is_relationshiptype",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("cvterm_id");
__PACKAGE__->add_unique_constraint("cvterm_c2", ["dbxref_id"]);
__PACKAGE__->add_unique_constraint("cvterm_c1", ["name", "cv_id", "is_obsolete"]);

=head1 RELATIONS

=head2 acquisitionprops

Type: has_many

Related object: L<PomCur::ChadoDB::Acquisitionprop>

=cut

__PACKAGE__->has_many(
  "acquisitionprops",
  "PomCur::ChadoDB::Acquisitionprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 acquisition_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::AcquisitionRelationship>

=cut

__PACKAGE__->has_many(
  "acquisition_relationships",
  "PomCur::ChadoDB::AcquisitionRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 analysisfeatureprops

Type: has_many

Related object: L<PomCur::ChadoDB::Analysisfeatureprop>

=cut

__PACKAGE__->has_many(
  "analysisfeatureprops",
  "PomCur::ChadoDB::Analysisfeatureprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 analysisprops

Type: has_many

Related object: L<PomCur::ChadoDB::Analysisprop>

=cut

__PACKAGE__->has_many(
  "analysisprops",
  "PomCur::ChadoDB::Analysisprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 arraydesign_platformtypes

Type: has_many

Related object: L<PomCur::ChadoDB::Arraydesign>

=cut

__PACKAGE__->has_many(
  "arraydesign_platformtypes",
  "PomCur::ChadoDB::Arraydesign",
  { "foreign.platformtype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 arraydesign_substratetypes

Type: has_many

Related object: L<PomCur::ChadoDB::Arraydesign>

=cut

__PACKAGE__->has_many(
  "arraydesign_substratetypes",
  "PomCur::ChadoDB::Arraydesign",
  { "foreign.substratetype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 arraydesignprops

Type: has_many

Related object: L<PomCur::ChadoDB::Arraydesignprop>

=cut

__PACKAGE__->has_many(
  "arraydesignprops",
  "PomCur::ChadoDB::Arraydesignprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 assayprops

Type: has_many

Related object: L<PomCur::ChadoDB::Assayprop>

=cut

__PACKAGE__->has_many(
  "assayprops",
  "PomCur::ChadoDB::Assayprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 biomaterialprops

Type: has_many

Related object: L<PomCur::ChadoDB::Biomaterialprop>

=cut

__PACKAGE__->has_many(
  "biomaterialprops",
  "PomCur::ChadoDB::Biomaterialprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 biomaterial_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::BiomaterialRelationship>

=cut

__PACKAGE__->has_many(
  "biomaterial_relationships",
  "PomCur::ChadoDB::BiomaterialRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 biomaterial_treatments

Type: has_many

Related object: L<PomCur::ChadoDB::BiomaterialTreatment>

=cut

__PACKAGE__->has_many(
  "biomaterial_treatments",
  "PomCur::ChadoDB::BiomaterialTreatment",
  { "foreign.unittype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::CellLineCvterm>

=cut

__PACKAGE__->has_many(
  "cell_line_cvterms",
  "PomCur::ChadoDB::CellLineCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_cvtermprops

Type: has_many

Related object: L<PomCur::ChadoDB::CellLineCvtermprop>

=cut

__PACKAGE__->has_many(
  "cell_line_cvtermprops",
  "PomCur::ChadoDB::CellLineCvtermprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_lineprops

Type: has_many

Related object: L<PomCur::ChadoDB::CellLineprop>

=cut

__PACKAGE__->has_many(
  "cell_lineprops",
  "PomCur::ChadoDB::CellLineprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::CellLineRelationship>

=cut

__PACKAGE__->has_many(
  "cell_line_relationships",
  "PomCur::ChadoDB::CellLineRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 contacts

Type: has_many

Related object: L<PomCur::ChadoDB::Contact>

=cut

__PACKAGE__->has_many(
  "contacts",
  "PomCur::ChadoDB::Contact",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 contact_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::ContactRelationship>

=cut

__PACKAGE__->has_many(
  "contact_relationships",
  "PomCur::ChadoDB::ContactRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 controls

Type: has_many

Related object: L<PomCur::ChadoDB::Control>

=cut

__PACKAGE__->has_many(
  "controls",
  "PomCur::ChadoDB::Control",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvprops

Type: has_many

Related object: L<PomCur::ChadoDB::Cvprop>

=cut

__PACKAGE__->has_many(
  "cvprops",
  "PomCur::ChadoDB::Cvprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cv

Type: belongs_to

Related object: L<PomCur::ChadoDB::Cv>

=cut

__PACKAGE__->belongs_to(
  "cv",
  "PomCur::ChadoDB::Cv",
  { cv_id => "cv_id" },
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

=head2 cvterm_dbxrefs

Type: has_many

Related object: L<PomCur::ChadoDB::CvtermDbxref>

=cut

__PACKAGE__->has_many(
  "cvterm_dbxrefs",
  "PomCur::ChadoDB::CvtermDbxref",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermpath_types

Type: has_many

Related object: L<PomCur::ChadoDB::Cvtermpath>

=cut

__PACKAGE__->has_many(
  "cvtermpath_types",
  "PomCur::ChadoDB::Cvtermpath",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermpath_objects

Type: has_many

Related object: L<PomCur::ChadoDB::Cvtermpath>

=cut

__PACKAGE__->has_many(
  "cvtermpath_objects",
  "PomCur::ChadoDB::Cvtermpath",
  { "foreign.object_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermpath_subjects

Type: has_many

Related object: L<PomCur::ChadoDB::Cvtermpath>

=cut

__PACKAGE__->has_many(
  "cvtermpath_subjects",
  "PomCur::ChadoDB::Cvtermpath",
  { "foreign.subject_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermprop_types

Type: has_many

Related object: L<PomCur::ChadoDB::Cvtermprop>

=cut

__PACKAGE__->has_many(
  "cvtermprop_types",
  "PomCur::ChadoDB::Cvtermprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermprop_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::Cvtermprop>

=cut

__PACKAGE__->has_many(
  "cvtermprop_cvterms",
  "PomCur::ChadoDB::Cvtermprop",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_types

Type: has_many

Related object: L<PomCur::ChadoDB::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_types",
  "PomCur::ChadoDB::CvtermRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_objects

Type: has_many

Related object: L<PomCur::ChadoDB::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_objects",
  "PomCur::ChadoDB::CvtermRelationship",
  { "foreign.object_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_subjects

Type: has_many

Related object: L<PomCur::ChadoDB::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_subjects",
  "PomCur::ChadoDB::CvtermRelationship",
  { "foreign.subject_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermsynonym_types

Type: has_many

Related object: L<PomCur::ChadoDB::Cvtermsynonym>

=cut

__PACKAGE__->has_many(
  "cvtermsynonym_types",
  "PomCur::ChadoDB::Cvtermsynonym",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermsynonym_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::Cvtermsynonym>

=cut

__PACKAGE__->has_many(
  "cvtermsynonym_cvterms",
  "PomCur::ChadoDB::Cvtermsynonym",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 dbxrefprops

Type: has_many

Related object: L<PomCur::ChadoDB::Dbxrefprop>

=cut

__PACKAGE__->has_many(
  "dbxrefprops",
  "PomCur::ChadoDB::Dbxrefprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 elements

Type: has_many

Related object: L<PomCur::ChadoDB::Element>

=cut

__PACKAGE__->has_many(
  "elements",
  "PomCur::ChadoDB::Element",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 element_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::ElementRelationship>

=cut

__PACKAGE__->has_many(
  "element_relationships",
  "PomCur::ChadoDB::ElementRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 elementresult_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::ElementresultRelationship>

=cut

__PACKAGE__->has_many(
  "elementresult_relationships",
  "PomCur::ChadoDB::ElementresultRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 environment_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::EnvironmentCvterm>

=cut

__PACKAGE__->has_many(
  "environment_cvterms",
  "PomCur::ChadoDB::EnvironmentCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 expression_cvterm_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::ExpressionCvterm>

=cut

__PACKAGE__->has_many(
  "expression_cvterm_cvterms",
  "PomCur::ChadoDB::ExpressionCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 expression_cvterm_cvterm_types

Type: has_many

Related object: L<PomCur::ChadoDB::ExpressionCvterm>

=cut

__PACKAGE__->has_many(
  "expression_cvterm_cvterm_types",
  "PomCur::ChadoDB::ExpressionCvterm",
  { "foreign.cvterm_type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 expression_cvtermprops

Type: has_many

Related object: L<PomCur::ChadoDB::ExpressionCvtermprop>

=cut

__PACKAGE__->has_many(
  "expression_cvtermprops",
  "PomCur::ChadoDB::ExpressionCvtermprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 expressionprops

Type: has_many

Related object: L<PomCur::ChadoDB::Expressionprop>

=cut

__PACKAGE__->has_many(
  "expressionprops",
  "PomCur::ChadoDB::Expressionprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 features

Type: has_many

Related object: L<PomCur::ChadoDB::Feature>

=cut

__PACKAGE__->has_many(
  "features",
  "PomCur::ChadoDB::Feature",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureCvterm>

=cut

__PACKAGE__->has_many(
  "feature_cvterms",
  "PomCur::ChadoDB::FeatureCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvtermprops

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureCvtermprop>

=cut

__PACKAGE__->has_many(
  "feature_cvtermprops",
  "PomCur::ChadoDB::FeatureCvtermprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_expressionprops

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureExpressionprop>

=cut

__PACKAGE__->has_many(
  "feature_expressionprops",
  "PomCur::ChadoDB::FeatureExpressionprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_genotypes

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureGenotype>

=cut

__PACKAGE__->has_many(
  "feature_genotypes",
  "PomCur::ChadoDB::FeatureGenotype",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featuremaps

Type: has_many

Related object: L<PomCur::ChadoDB::Featuremap>

=cut

__PACKAGE__->has_many(
  "featuremaps",
  "PomCur::ChadoDB::Featuremap",
  { "foreign.unittype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureprops

Type: has_many

Related object: L<PomCur::ChadoDB::Featureprop>

=cut

__PACKAGE__->has_many(
  "featureprops",
  "PomCur::ChadoDB::Featureprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_pubprops

Type: has_many

Related object: L<PomCur::ChadoDB::FeaturePubprop>

=cut

__PACKAGE__->has_many(
  "feature_pubprops",
  "PomCur::ChadoDB::FeaturePubprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureRelationship>

=cut

__PACKAGE__->has_many(
  "feature_relationships",
  "PomCur::ChadoDB::FeatureRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationshipprops

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureRelationshipprop>

=cut

__PACKAGE__->has_many(
  "feature_relationshipprops",
  "PomCur::ChadoDB::FeatureRelationshipprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 libraries

Type: has_many

Related object: L<PomCur::ChadoDB::Library>

=cut

__PACKAGE__->has_many(
  "libraries",
  "PomCur::ChadoDB::Library",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 library_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::LibraryCvterm>

=cut

__PACKAGE__->has_many(
  "library_cvterms",
  "PomCur::ChadoDB::LibraryCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 libraryprops

Type: has_many

Related object: L<PomCur::ChadoDB::Libraryprop>

=cut

__PACKAGE__->has_many(
  "libraryprops",
  "PomCur::ChadoDB::Libraryprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_experiments

Type: has_many

Related object: L<PomCur::ChadoDB::NdExperiment>

=cut

__PACKAGE__->has_many(
  "nd_experiments",
  "PomCur::ChadoDB::NdExperiment",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_experimentprops

Type: has_many

Related object: L<PomCur::ChadoDB::NdExperimentprop>

=cut

__PACKAGE__->has_many(
  "nd_experimentprops",
  "PomCur::ChadoDB::NdExperimentprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_experiment_stocks

Type: has_many

Related object: L<PomCur::ChadoDB::NdExperimentStock>

=cut

__PACKAGE__->has_many(
  "nd_experiment_stocks",
  "PomCur::ChadoDB::NdExperimentStock",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_experiment_stockprops

Type: has_many

Related object: L<PomCur::ChadoDB::NdExperimentStockprop>

=cut

__PACKAGE__->has_many(
  "nd_experiment_stockprops",
  "PomCur::ChadoDB::NdExperimentStockprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_geolocationprops

Type: has_many

Related object: L<PomCur::ChadoDB::NdGeolocationprop>

=cut

__PACKAGE__->has_many(
  "nd_geolocationprops",
  "PomCur::ChadoDB::NdGeolocationprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_protocolprops

Type: has_many

Related object: L<PomCur::ChadoDB::NdProtocolprop>

=cut

__PACKAGE__->has_many(
  "nd_protocolprops",
  "PomCur::ChadoDB::NdProtocolprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_protocol_reagents

Type: has_many

Related object: L<PomCur::ChadoDB::NdProtocolReagent>

=cut

__PACKAGE__->has_many(
  "nd_protocol_reagents",
  "PomCur::ChadoDB::NdProtocolReagent",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_reagents

Type: has_many

Related object: L<PomCur::ChadoDB::NdReagent>

=cut

__PACKAGE__->has_many(
  "nd_reagents",
  "PomCur::ChadoDB::NdReagent",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_reagentprops

Type: has_many

Related object: L<PomCur::ChadoDB::NdReagentprop>

=cut

__PACKAGE__->has_many(
  "nd_reagentprops",
  "PomCur::ChadoDB::NdReagentprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_reagent_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::NdReagentRelationship>

=cut

__PACKAGE__->has_many(
  "nd_reagent_relationships",
  "PomCur::ChadoDB::NdReagentRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organismprops

Type: has_many

Related object: L<PomCur::ChadoDB::Organismprop>

=cut

__PACKAGE__->has_many(
  "organismprops",
  "PomCur::ChadoDB::Organismprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phendescs

Type: has_many

Related object: L<PomCur::ChadoDB::Phendesc>

=cut

__PACKAGE__->has_many(
  "phendescs",
  "PomCur::ChadoDB::Phendesc",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_assays

Type: has_many

Related object: L<PomCur::ChadoDB::Phenotype>

=cut

__PACKAGE__->has_many(
  "phenotype_assays",
  "PomCur::ChadoDB::Phenotype",
  { "foreign.assay_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_attrs

Type: has_many

Related object: L<PomCur::ChadoDB::Phenotype>

=cut

__PACKAGE__->has_many(
  "phenotype_attrs",
  "PomCur::ChadoDB::Phenotype",
  { "foreign.attr_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_observables

Type: has_many

Related object: L<PomCur::ChadoDB::Phenotype>

=cut

__PACKAGE__->has_many(
  "phenotype_observables",
  "PomCur::ChadoDB::Phenotype",
  { "foreign.observable_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_cvalues

Type: has_many

Related object: L<PomCur::ChadoDB::Phenotype>

=cut

__PACKAGE__->has_many(
  "phenotype_cvalues",
  "PomCur::ChadoDB::Phenotype",
  { "foreign.cvalue_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_comparison_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::PhenotypeComparisonCvterm>

=cut

__PACKAGE__->has_many(
  "phenotype_comparison_cvterms",
  "PomCur::ChadoDB::PhenotypeComparisonCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::PhenotypeCvterm>

=cut

__PACKAGE__->has_many(
  "phenotype_cvterms",
  "PomCur::ChadoDB::PhenotypeCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenstatements

Type: has_many

Related object: L<PomCur::ChadoDB::Phenstatement>

=cut

__PACKAGE__->has_many(
  "phenstatements",
  "PomCur::ChadoDB::Phenstatement",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylonodes

Type: has_many

Related object: L<PomCur::ChadoDB::Phylonode>

=cut

__PACKAGE__->has_many(
  "phylonodes",
  "PomCur::ChadoDB::Phylonode",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylonodeprops

Type: has_many

Related object: L<PomCur::ChadoDB::Phylonodeprop>

=cut

__PACKAGE__->has_many(
  "phylonodeprops",
  "PomCur::ChadoDB::Phylonodeprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylonode_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::PhylonodeRelationship>

=cut

__PACKAGE__->has_many(
  "phylonode_relationships",
  "PomCur::ChadoDB::PhylonodeRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylotrees

Type: has_many

Related object: L<PomCur::ChadoDB::Phylotree>

=cut

__PACKAGE__->has_many(
  "phylotrees",
  "PomCur::ChadoDB::Phylotree",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 projectprops

Type: has_many

Related object: L<PomCur::ChadoDB::Projectprop>

=cut

__PACKAGE__->has_many(
  "projectprops",
  "PomCur::ChadoDB::Projectprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 project_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::ProjectRelationship>

=cut

__PACKAGE__->has_many(
  "project_relationships",
  "PomCur::ChadoDB::ProjectRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 protocols

Type: has_many

Related object: L<PomCur::ChadoDB::Protocol>

=cut

__PACKAGE__->has_many(
  "protocols",
  "PomCur::ChadoDB::Protocol",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 protocolparam_unittypes

Type: has_many

Related object: L<PomCur::ChadoDB::Protocolparam>

=cut

__PACKAGE__->has_many(
  "protocolparam_unittypes",
  "PomCur::ChadoDB::Protocolparam",
  { "foreign.unittype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 protocolparam_datatypes

Type: has_many

Related object: L<PomCur::ChadoDB::Protocolparam>

=cut

__PACKAGE__->has_many(
  "protocolparam_datatypes",
  "PomCur::ChadoDB::Protocolparam",
  { "foreign.datatype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubs

Type: has_many

Related object: L<PomCur::ChadoDB::Pub>

=cut

__PACKAGE__->has_many(
  "pubs",
  "PomCur::ChadoDB::Pub",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubprops

Type: has_many

Related object: L<PomCur::ChadoDB::Pubprop>

=cut

__PACKAGE__->has_many(
  "pubprops",
  "PomCur::ChadoDB::Pubprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::PubRelationship>

=cut

__PACKAGE__->has_many(
  "pub_relationships",
  "PomCur::ChadoDB::PubRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 quantificationprops

Type: has_many

Related object: L<PomCur::ChadoDB::Quantificationprop>

=cut

__PACKAGE__->has_many(
  "quantificationprops",
  "PomCur::ChadoDB::Quantificationprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 quantification_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::QuantificationRelationship>

=cut

__PACKAGE__->has_many(
  "quantification_relationships",
  "PomCur::ChadoDB::QuantificationRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stocks

Type: has_many

Related object: L<PomCur::ChadoDB::Stock>

=cut

__PACKAGE__->has_many(
  "stocks",
  "PomCur::ChadoDB::Stock",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stockcollections

Type: has_many

Related object: L<PomCur::ChadoDB::Stockcollection>

=cut

__PACKAGE__->has_many(
  "stockcollections",
  "PomCur::ChadoDB::Stockcollection",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stockcollectionprops

Type: has_many

Related object: L<PomCur::ChadoDB::Stockcollectionprop>

=cut

__PACKAGE__->has_many(
  "stockcollectionprops",
  "PomCur::ChadoDB::Stockcollectionprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::StockCvterm>

=cut

__PACKAGE__->has_many(
  "stock_cvterms",
  "PomCur::ChadoDB::StockCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_dbxrefprops

Type: has_many

Related object: L<PomCur::ChadoDB::StockDbxrefprop>

=cut

__PACKAGE__->has_many(
  "stock_dbxrefprops",
  "PomCur::ChadoDB::StockDbxrefprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stockprops

Type: has_many

Related object: L<PomCur::ChadoDB::Stockprop>

=cut

__PACKAGE__->has_many(
  "stockprops",
  "PomCur::ChadoDB::Stockprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_relationships

Type: has_many

Related object: L<PomCur::ChadoDB::StockRelationship>

=cut

__PACKAGE__->has_many(
  "stock_relationships",
  "PomCur::ChadoDB::StockRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_relationship_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::StockRelationshipCvterm>

=cut

__PACKAGE__->has_many(
  "stock_relationship_cvterms",
  "PomCur::ChadoDB::StockRelationshipCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 studydesignprops

Type: has_many

Related object: L<PomCur::ChadoDB::Studydesignprop>

=cut

__PACKAGE__->has_many(
  "studydesignprops",
  "PomCur::ChadoDB::Studydesignprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 studyfactors

Type: has_many

Related object: L<PomCur::ChadoDB::Studyfactor>

=cut

__PACKAGE__->has_many(
  "studyfactors",
  "PomCur::ChadoDB::Studyfactor",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 studyprops

Type: has_many

Related object: L<PomCur::ChadoDB::Studyprop>

=cut

__PACKAGE__->has_many(
  "studyprops",
  "PomCur::ChadoDB::Studyprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 studyprop_features

Type: has_many

Related object: L<PomCur::ChadoDB::StudypropFeature>

=cut

__PACKAGE__->has_many(
  "studyprop_features",
  "PomCur::ChadoDB::StudypropFeature",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 synonyms

Type: has_many

Related object: L<PomCur::ChadoDB::Synonym>

=cut

__PACKAGE__->has_many(
  "synonyms",
  "PomCur::ChadoDB::Synonym",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 treatments

Type: has_many

Related object: L<PomCur::ChadoDB::Treatment>

=cut

__PACKAGE__->has_many(
  "treatments",
  "PomCur::ChadoDB::Treatment",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:u/RKQVQ6aNHYtPmTlLOh3g


=head2 db_accession

 Usage   : my $db_accession = $cvterm->db_accession();
 Function: Return the identifier for this term in "<db>:<identifier>" form,
           eg. "GO:0004022"
 Args    : none
 Returns : the database accession

=cut
sub db_accession
{
  my $cvterm = shift;

  my $dbxref = $cvterm->dbxref();
  my $db = $dbxref->db();

  return $db->name() . ':' . $dbxref->accession();
}

=head2 synonyms

 Usage   : my @cvterm_synonyms = $cvterm->synonyms();
 Function: An alias for cvtermsynonym_cvterms(), returns the Cvtermsynonyms of
           this cvterm
 Args    : none
 Returns : return synonyms

=cut
sub synonyms
{
  return cvtermsynonym_cvterms(@_);
}

__PACKAGE__->meta->make_immutable;
1;
