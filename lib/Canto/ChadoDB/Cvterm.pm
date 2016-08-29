package Canto::ChadoDB::Cvterm;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::Cvterm

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

Related object: L<Canto::ChadoDB::Acquisitionprop>

=cut

__PACKAGE__->has_many(
  "acquisitionprops",
  "Canto::ChadoDB::Acquisitionprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 acquisition_relationships

Type: has_many

Related object: L<Canto::ChadoDB::AcquisitionRelationship>

=cut

__PACKAGE__->has_many(
  "acquisition_relationships",
  "Canto::ChadoDB::AcquisitionRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 analysisfeatureprops

Type: has_many

Related object: L<Canto::ChadoDB::Analysisfeatureprop>

=cut

__PACKAGE__->has_many(
  "analysisfeatureprops",
  "Canto::ChadoDB::Analysisfeatureprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 analysisprops

Type: has_many

Related object: L<Canto::ChadoDB::Analysisprop>

=cut

__PACKAGE__->has_many(
  "analysisprops",
  "Canto::ChadoDB::Analysisprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 arraydesign_platformtypes

Type: has_many

Related object: L<Canto::ChadoDB::Arraydesign>

=cut

__PACKAGE__->has_many(
  "arraydesign_platformtypes",
  "Canto::ChadoDB::Arraydesign",
  { "foreign.platformtype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 arraydesign_substratetypes

Type: has_many

Related object: L<Canto::ChadoDB::Arraydesign>

=cut

__PACKAGE__->has_many(
  "arraydesign_substratetypes",
  "Canto::ChadoDB::Arraydesign",
  { "foreign.substratetype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 arraydesignprops

Type: has_many

Related object: L<Canto::ChadoDB::Arraydesignprop>

=cut

__PACKAGE__->has_many(
  "arraydesignprops",
  "Canto::ChadoDB::Arraydesignprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 assayprops

Type: has_many

Related object: L<Canto::ChadoDB::Assayprop>

=cut

__PACKAGE__->has_many(
  "assayprops",
  "Canto::ChadoDB::Assayprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 biomaterialprops

Type: has_many

Related object: L<Canto::ChadoDB::Biomaterialprop>

=cut

__PACKAGE__->has_many(
  "biomaterialprops",
  "Canto::ChadoDB::Biomaterialprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 biomaterial_relationships

Type: has_many

Related object: L<Canto::ChadoDB::BiomaterialRelationship>

=cut

__PACKAGE__->has_many(
  "biomaterial_relationships",
  "Canto::ChadoDB::BiomaterialRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 biomaterial_treatments

Type: has_many

Related object: L<Canto::ChadoDB::BiomaterialTreatment>

=cut

__PACKAGE__->has_many(
  "biomaterial_treatments",
  "Canto::ChadoDB::BiomaterialTreatment",
  { "foreign.unittype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_cvterms

Type: has_many

Related object: L<Canto::ChadoDB::CellLineCvterm>

=cut

__PACKAGE__->has_many(
  "cell_line_cvterms",
  "Canto::ChadoDB::CellLineCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_cvtermprops

Type: has_many

Related object: L<Canto::ChadoDB::CellLineCvtermprop>

=cut

__PACKAGE__->has_many(
  "cell_line_cvtermprops",
  "Canto::ChadoDB::CellLineCvtermprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_lineprops

Type: has_many

Related object: L<Canto::ChadoDB::CellLineprop>

=cut

__PACKAGE__->has_many(
  "cell_lineprops",
  "Canto::ChadoDB::CellLineprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_relationships

Type: has_many

Related object: L<Canto::ChadoDB::CellLineRelationship>

=cut

__PACKAGE__->has_many(
  "cell_line_relationships",
  "Canto::ChadoDB::CellLineRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 contacts

Type: has_many

Related object: L<Canto::ChadoDB::Contact>

=cut

__PACKAGE__->has_many(
  "contacts",
  "Canto::ChadoDB::Contact",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 contact_relationships

Type: has_many

Related object: L<Canto::ChadoDB::ContactRelationship>

=cut

__PACKAGE__->has_many(
  "contact_relationships",
  "Canto::ChadoDB::ContactRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 controls

Type: has_many

Related object: L<Canto::ChadoDB::Control>

=cut

__PACKAGE__->has_many(
  "controls",
  "Canto::ChadoDB::Control",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvprops

Type: has_many

Related object: L<Canto::ChadoDB::Cvprop>

=cut

__PACKAGE__->has_many(
  "cvprops",
  "Canto::ChadoDB::Cvprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cv

Type: belongs_to

Related object: L<Canto::ChadoDB::Cv>

=cut

__PACKAGE__->belongs_to(
  "cv",
  "Canto::ChadoDB::Cv",
  { cv_id => "cv_id" },
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

=head2 cvterm_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::CvtermDbxref>

=cut

__PACKAGE__->has_many(
  "cvterm_dbxrefs",
  "Canto::ChadoDB::CvtermDbxref",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermpath_types

Type: has_many

Related object: L<Canto::ChadoDB::Cvtermpath>

=cut

__PACKAGE__->has_many(
  "cvtermpath_types",
  "Canto::ChadoDB::Cvtermpath",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermpath_objects

Type: has_many

Related object: L<Canto::ChadoDB::Cvtermpath>

=cut

__PACKAGE__->has_many(
  "cvtermpath_objects",
  "Canto::ChadoDB::Cvtermpath",
  { "foreign.object_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermpath_subjects

Type: has_many

Related object: L<Canto::ChadoDB::Cvtermpath>

=cut

__PACKAGE__->has_many(
  "cvtermpath_subjects",
  "Canto::ChadoDB::Cvtermpath",
  { "foreign.subject_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermprop_types

Type: has_many

Related object: L<Canto::ChadoDB::Cvtermprop>

=cut

__PACKAGE__->has_many(
  "cvtermprop_types",
  "Canto::ChadoDB::Cvtermprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermprop_cvterms

Type: has_many

Related object: L<Canto::ChadoDB::Cvtermprop>

=cut

__PACKAGE__->has_many(
  "cvtermprop_cvterms",
  "Canto::ChadoDB::Cvtermprop",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_types

Type: has_many

Related object: L<Canto::ChadoDB::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_types",
  "Canto::ChadoDB::CvtermRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_objects

Type: has_many

Related object: L<Canto::ChadoDB::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_objects",
  "Canto::ChadoDB::CvtermRelationship",
  { "foreign.object_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_subjects

Type: has_many

Related object: L<Canto::ChadoDB::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_subjects",
  "Canto::ChadoDB::CvtermRelationship",
  { "foreign.subject_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermsynonym_types

Type: has_many

Related object: L<Canto::ChadoDB::Cvtermsynonym>

=cut

__PACKAGE__->has_many(
  "cvtermsynonym_types",
  "Canto::ChadoDB::Cvtermsynonym",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermsynonym_cvterms

Type: has_many

Related object: L<Canto::ChadoDB::Cvtermsynonym>

=cut

__PACKAGE__->has_many(
  "cvtermsynonym_cvterms",
  "Canto::ChadoDB::Cvtermsynonym",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 dbxrefprops

Type: has_many

Related object: L<Canto::ChadoDB::Dbxrefprop>

=cut

__PACKAGE__->has_many(
  "dbxrefprops",
  "Canto::ChadoDB::Dbxrefprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 elements

Type: has_many

Related object: L<Canto::ChadoDB::Element>

=cut

__PACKAGE__->has_many(
  "elements",
  "Canto::ChadoDB::Element",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 element_relationships

Type: has_many

Related object: L<Canto::ChadoDB::ElementRelationship>

=cut

__PACKAGE__->has_many(
  "element_relationships",
  "Canto::ChadoDB::ElementRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 elementresult_relationships

Type: has_many

Related object: L<Canto::ChadoDB::ElementresultRelationship>

=cut

__PACKAGE__->has_many(
  "elementresult_relationships",
  "Canto::ChadoDB::ElementresultRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 environment_cvterms

Type: has_many

Related object: L<Canto::ChadoDB::EnvironmentCvterm>

=cut

__PACKAGE__->has_many(
  "environment_cvterms",
  "Canto::ChadoDB::EnvironmentCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 expression_cvterm_cvterms

Type: has_many

Related object: L<Canto::ChadoDB::ExpressionCvterm>

=cut

__PACKAGE__->has_many(
  "expression_cvterm_cvterms",
  "Canto::ChadoDB::ExpressionCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 expression_cvterm_cvterm_types

Type: has_many

Related object: L<Canto::ChadoDB::ExpressionCvterm>

=cut

__PACKAGE__->has_many(
  "expression_cvterm_cvterm_types",
  "Canto::ChadoDB::ExpressionCvterm",
  { "foreign.cvterm_type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 expression_cvtermprops

Type: has_many

Related object: L<Canto::ChadoDB::ExpressionCvtermprop>

=cut

__PACKAGE__->has_many(
  "expression_cvtermprops",
  "Canto::ChadoDB::ExpressionCvtermprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 expressionprops

Type: has_many

Related object: L<Canto::ChadoDB::Expressionprop>

=cut

__PACKAGE__->has_many(
  "expressionprops",
  "Canto::ChadoDB::Expressionprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 features

Type: has_many

Related object: L<Canto::ChadoDB::Feature>

=cut

__PACKAGE__->has_many(
  "features",
  "Canto::ChadoDB::Feature",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvterms

Type: has_many

Related object: L<Canto::ChadoDB::FeatureCvterm>

=cut

__PACKAGE__->has_many(
  "feature_cvterms",
  "Canto::ChadoDB::FeatureCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvtermprops

Type: has_many

Related object: L<Canto::ChadoDB::FeatureCvtermprop>

=cut

__PACKAGE__->has_many(
  "feature_cvtermprops",
  "Canto::ChadoDB::FeatureCvtermprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_expressionprops

Type: has_many

Related object: L<Canto::ChadoDB::FeatureExpressionprop>

=cut

__PACKAGE__->has_many(
  "feature_expressionprops",
  "Canto::ChadoDB::FeatureExpressionprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_genotypes

Type: has_many

Related object: L<Canto::ChadoDB::FeatureGenotype>

=cut

__PACKAGE__->has_many(
  "feature_genotypes",
  "Canto::ChadoDB::FeatureGenotype",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featuremaps

Type: has_many

Related object: L<Canto::ChadoDB::Featuremap>

=cut

__PACKAGE__->has_many(
  "featuremaps",
  "Canto::ChadoDB::Featuremap",
  { "foreign.unittype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureprops

Type: has_many

Related object: L<Canto::ChadoDB::Featureprop>

=cut

__PACKAGE__->has_many(
  "featureprops",
  "Canto::ChadoDB::Featureprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_pubprops

Type: has_many

Related object: L<Canto::ChadoDB::FeaturePubprop>

=cut

__PACKAGE__->has_many(
  "feature_pubprops",
  "Canto::ChadoDB::FeaturePubprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationships

Type: has_many

Related object: L<Canto::ChadoDB::FeatureRelationship>

=cut

__PACKAGE__->has_many(
  "feature_relationships",
  "Canto::ChadoDB::FeatureRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationshipprops

Type: has_many

Related object: L<Canto::ChadoDB::FeatureRelationshipprop>

=cut

__PACKAGE__->has_many(
  "feature_relationshipprops",
  "Canto::ChadoDB::FeatureRelationshipprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 libraries

Type: has_many

Related object: L<Canto::ChadoDB::Library>

=cut

__PACKAGE__->has_many(
  "libraries",
  "Canto::ChadoDB::Library",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 library_cvterms

Type: has_many

Related object: L<Canto::ChadoDB::LibraryCvterm>

=cut

__PACKAGE__->has_many(
  "library_cvterms",
  "Canto::ChadoDB::LibraryCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 libraryprops

Type: has_many

Related object: L<Canto::ChadoDB::Libraryprop>

=cut

__PACKAGE__->has_many(
  "libraryprops",
  "Canto::ChadoDB::Libraryprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_experiments

Type: has_many

Related object: L<Canto::ChadoDB::NdExperiment>

=cut

__PACKAGE__->has_many(
  "nd_experiments",
  "Canto::ChadoDB::NdExperiment",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_experimentprops

Type: has_many

Related object: L<Canto::ChadoDB::NdExperimentprop>

=cut

__PACKAGE__->has_many(
  "nd_experimentprops",
  "Canto::ChadoDB::NdExperimentprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_experiment_stocks

Type: has_many

Related object: L<Canto::ChadoDB::NdExperimentStock>

=cut

__PACKAGE__->has_many(
  "nd_experiment_stocks",
  "Canto::ChadoDB::NdExperimentStock",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_experiment_stockprops

Type: has_many

Related object: L<Canto::ChadoDB::NdExperimentStockprop>

=cut

__PACKAGE__->has_many(
  "nd_experiment_stockprops",
  "Canto::ChadoDB::NdExperimentStockprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_geolocationprops

Type: has_many

Related object: L<Canto::ChadoDB::NdGeolocationprop>

=cut

__PACKAGE__->has_many(
  "nd_geolocationprops",
  "Canto::ChadoDB::NdGeolocationprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_protocolprops

Type: has_many

Related object: L<Canto::ChadoDB::NdProtocolprop>

=cut

__PACKAGE__->has_many(
  "nd_protocolprops",
  "Canto::ChadoDB::NdProtocolprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_protocol_reagents

Type: has_many

Related object: L<Canto::ChadoDB::NdProtocolReagent>

=cut

__PACKAGE__->has_many(
  "nd_protocol_reagents",
  "Canto::ChadoDB::NdProtocolReagent",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_reagents

Type: has_many

Related object: L<Canto::ChadoDB::NdReagent>

=cut

__PACKAGE__->has_many(
  "nd_reagents",
  "Canto::ChadoDB::NdReagent",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_reagentprops

Type: has_many

Related object: L<Canto::ChadoDB::NdReagentprop>

=cut

__PACKAGE__->has_many(
  "nd_reagentprops",
  "Canto::ChadoDB::NdReagentprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_reagent_relationships

Type: has_many

Related object: L<Canto::ChadoDB::NdReagentRelationship>

=cut

__PACKAGE__->has_many(
  "nd_reagent_relationships",
  "Canto::ChadoDB::NdReagentRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organismprops

Type: has_many

Related object: L<Canto::ChadoDB::Organismprop>

=cut

__PACKAGE__->has_many(
  "organismprops",
  "Canto::ChadoDB::Organismprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phendescs

Type: has_many

Related object: L<Canto::ChadoDB::Phendesc>

=cut

__PACKAGE__->has_many(
  "phendescs",
  "Canto::ChadoDB::Phendesc",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_assays

Type: has_many

Related object: L<Canto::ChadoDB::Phenotype>

=cut

__PACKAGE__->has_many(
  "phenotype_assays",
  "Canto::ChadoDB::Phenotype",
  { "foreign.assay_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_attrs

Type: has_many

Related object: L<Canto::ChadoDB::Phenotype>

=cut

__PACKAGE__->has_many(
  "phenotype_attrs",
  "Canto::ChadoDB::Phenotype",
  { "foreign.attr_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_observables

Type: has_many

Related object: L<Canto::ChadoDB::Phenotype>

=cut

__PACKAGE__->has_many(
  "phenotype_observables",
  "Canto::ChadoDB::Phenotype",
  { "foreign.observable_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_cvalues

Type: has_many

Related object: L<Canto::ChadoDB::Phenotype>

=cut

__PACKAGE__->has_many(
  "phenotype_cvalues",
  "Canto::ChadoDB::Phenotype",
  { "foreign.cvalue_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_comparison_cvterms

Type: has_many

Related object: L<Canto::ChadoDB::PhenotypeComparisonCvterm>

=cut

__PACKAGE__->has_many(
  "phenotype_comparison_cvterms",
  "Canto::ChadoDB::PhenotypeComparisonCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenotype_cvterms

Type: has_many

Related object: L<Canto::ChadoDB::PhenotypeCvterm>

=cut

__PACKAGE__->has_many(
  "phenotype_cvterms",
  "Canto::ChadoDB::PhenotypeCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phenstatements

Type: has_many

Related object: L<Canto::ChadoDB::Phenstatement>

=cut

__PACKAGE__->has_many(
  "phenstatements",
  "Canto::ChadoDB::Phenstatement",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylonodes

Type: has_many

Related object: L<Canto::ChadoDB::Phylonode>

=cut

__PACKAGE__->has_many(
  "phylonodes",
  "Canto::ChadoDB::Phylonode",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylonodeprops

Type: has_many

Related object: L<Canto::ChadoDB::Phylonodeprop>

=cut

__PACKAGE__->has_many(
  "phylonodeprops",
  "Canto::ChadoDB::Phylonodeprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylonode_relationships

Type: has_many

Related object: L<Canto::ChadoDB::PhylonodeRelationship>

=cut

__PACKAGE__->has_many(
  "phylonode_relationships",
  "Canto::ChadoDB::PhylonodeRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylotrees

Type: has_many

Related object: L<Canto::ChadoDB::Phylotree>

=cut

__PACKAGE__->has_many(
  "phylotrees",
  "Canto::ChadoDB::Phylotree",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 projectprops

Type: has_many

Related object: L<Canto::ChadoDB::Projectprop>

=cut

__PACKAGE__->has_many(
  "projectprops",
  "Canto::ChadoDB::Projectprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 project_relationships

Type: has_many

Related object: L<Canto::ChadoDB::ProjectRelationship>

=cut

__PACKAGE__->has_many(
  "project_relationships",
  "Canto::ChadoDB::ProjectRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 protocols

Type: has_many

Related object: L<Canto::ChadoDB::Protocol>

=cut

__PACKAGE__->has_many(
  "protocols",
  "Canto::ChadoDB::Protocol",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 protocolparam_unittypes

Type: has_many

Related object: L<Canto::ChadoDB::Protocolparam>

=cut

__PACKAGE__->has_many(
  "protocolparam_unittypes",
  "Canto::ChadoDB::Protocolparam",
  { "foreign.unittype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 protocolparam_datatypes

Type: has_many

Related object: L<Canto::ChadoDB::Protocolparam>

=cut

__PACKAGE__->has_many(
  "protocolparam_datatypes",
  "Canto::ChadoDB::Protocolparam",
  { "foreign.datatype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubs

Type: has_many

Related object: L<Canto::ChadoDB::Pub>

=cut

__PACKAGE__->has_many(
  "pubs",
  "Canto::ChadoDB::Pub",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubprops

Type: has_many

Related object: L<Canto::ChadoDB::Pubprop>

=cut

__PACKAGE__->has_many(
  "pubprops",
  "Canto::ChadoDB::Pubprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_relationships

Type: has_many

Related object: L<Canto::ChadoDB::PubRelationship>

=cut

__PACKAGE__->has_many(
  "pub_relationships",
  "Canto::ChadoDB::PubRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 quantificationprops

Type: has_many

Related object: L<Canto::ChadoDB::Quantificationprop>

=cut

__PACKAGE__->has_many(
  "quantificationprops",
  "Canto::ChadoDB::Quantificationprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 quantification_relationships

Type: has_many

Related object: L<Canto::ChadoDB::QuantificationRelationship>

=cut

__PACKAGE__->has_many(
  "quantification_relationships",
  "Canto::ChadoDB::QuantificationRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stocks

Type: has_many

Related object: L<Canto::ChadoDB::Stock>

=cut

__PACKAGE__->has_many(
  "stocks",
  "Canto::ChadoDB::Stock",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stockcollections

Type: has_many

Related object: L<Canto::ChadoDB::Stockcollection>

=cut

__PACKAGE__->has_many(
  "stockcollections",
  "Canto::ChadoDB::Stockcollection",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stockcollectionprops

Type: has_many

Related object: L<Canto::ChadoDB::Stockcollectionprop>

=cut

__PACKAGE__->has_many(
  "stockcollectionprops",
  "Canto::ChadoDB::Stockcollectionprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_cvterms

Type: has_many

Related object: L<Canto::ChadoDB::StockCvterm>

=cut

__PACKAGE__->has_many(
  "stock_cvterms",
  "Canto::ChadoDB::StockCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_dbxrefprops

Type: has_many

Related object: L<Canto::ChadoDB::StockDbxrefprop>

=cut

__PACKAGE__->has_many(
  "stock_dbxrefprops",
  "Canto::ChadoDB::StockDbxrefprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stockprops

Type: has_many

Related object: L<Canto::ChadoDB::Stockprop>

=cut

__PACKAGE__->has_many(
  "stockprops",
  "Canto::ChadoDB::Stockprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_relationships

Type: has_many

Related object: L<Canto::ChadoDB::StockRelationship>

=cut

__PACKAGE__->has_many(
  "stock_relationships",
  "Canto::ChadoDB::StockRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_relationship_cvterms

Type: has_many

Related object: L<Canto::ChadoDB::StockRelationshipCvterm>

=cut

__PACKAGE__->has_many(
  "stock_relationship_cvterms",
  "Canto::ChadoDB::StockRelationshipCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 studydesignprops

Type: has_many

Related object: L<Canto::ChadoDB::Studydesignprop>

=cut

__PACKAGE__->has_many(
  "studydesignprops",
  "Canto::ChadoDB::Studydesignprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 studyfactors

Type: has_many

Related object: L<Canto::ChadoDB::Studyfactor>

=cut

__PACKAGE__->has_many(
  "studyfactors",
  "Canto::ChadoDB::Studyfactor",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 studyprops

Type: has_many

Related object: L<Canto::ChadoDB::Studyprop>

=cut

__PACKAGE__->has_many(
  "studyprops",
  "Canto::ChadoDB::Studyprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 studyprop_features

Type: has_many

Related object: L<Canto::ChadoDB::StudypropFeature>

=cut

__PACKAGE__->has_many(
  "studyprop_features",
  "Canto::ChadoDB::StudypropFeature",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 synonyms

Type: has_many

Related object: L<Canto::ChadoDB::Synonym>

=cut

__PACKAGE__->has_many(
  "synonyms",
  "Canto::ChadoDB::Synonym",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 treatments

Type: has_many

Related object: L<Canto::ChadoDB::Treatment>

=cut

__PACKAGE__->has_many(
  "treatments",
  "Canto::ChadoDB::Treatment",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:u/RKQVQ6aNHYtPmTlLOh3g

=head2 cvtermprops

Type: has_many

Related object: L<Bio::Chado::Schema::Result::Cv::Cvtermprop>

=cut

__PACKAGE__->has_many(
  "cvtermprops",
  "Canto::ChadoDB::Cvtermprop",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


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
