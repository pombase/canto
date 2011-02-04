package PomCur::ChadoDB::Feature;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::ChadoDB::Feature

=head1 DESCRIPTION

A feature is a biological sequence or a
section of a biological sequence, or a collection of such
sections. Examples include genes, exons, transcripts, regulatory
regions, polypeptides, protein domains, chromosome sequences, sequence
variations, cross-genome match regions such as hits and HSPs and so
on; see the Sequence Ontology for more. The combination of
organism_id, uniquename and type_id should be unique.

=cut

__PACKAGE__->table("feature");

=head1 ACCESSORS

=head2 feature_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_feature_id_seq'

=head2 dbxref_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

An optional primary public stable
identifier for this feature. Secondary identifiers and external
dbxrefs go in the table feature_dbxref.

=head2 organism_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The organism to which this feature
belongs. This column is mandatory.

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

The optional human-readable common name for
a feature, for display purposes.

=head2 uniquename

  data_type: 'text'
  is_nullable: 0

The unique name for a feature; may
not be necessarily be particularly human-readable, although this is
preferred. This name must be unique for this type of feature within
this organism.

=head2 residues

  data_type: 'text'
  is_nullable: 1

A sequence of alphabetic characters
representing biological residues (nucleic acids, amino acids). This
column does not need to be manifested for all features; it is optional
for features such as exons where the residues can be derived from the
featureloc. It is recommended that the value for this column be
manifested for features which may may non-contiguous sublocations (e.g.
transcripts), since derivation at query time is non-trivial. For
expressed sequence, the DNA sequence should be used rather than the
RNA sequence. The default storage method for the residues column is
EXTERNAL, which will store it uncompressed to make substring operations
faster.

=head2 seqlen

  data_type: 'integer'
  is_nullable: 1

The length of the residue feature. See
column:residues. This column is partially redundant with the residues
column, and also with featureloc. This column is required because the
location may be unknown and the residue sequence may not be
manifested, yet it may be desirable to store and query the length of
the feature. The seqlen should always be manifested where the length
of the sequence is known.

=head2 md5checksum

  data_type: 'char'
  is_nullable: 1
  size: 32

The 32-character checksum of the sequence,
calculated using the MD5 algorithm. This is practically guaranteed to
be unique for any feature. This column thus acts as a unique
identifier on the mathematical sequence.

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

A required reference to a table:cvterm
giving the feature type. This will typically be a Sequence Ontology
identifier. This column is thus used to subclass the feature table.

=head2 is_analysis

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

Boolean indicating whether this
feature is annotated or the result of an automated analysis. Analysis
results also use the companalysis module. Note that the dividing line
between analysis and annotation may be fuzzy, this should be determined on
a per-project basis in a consistent manner. One requirement is that
there should only be one non-analysis version of each wild-type gene
feature in a genome, whereas the same gene feature can be predicted
multiple times in different analyses.

=head2 is_obsolete

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

Boolean indicating whether this
feature has been obsoleted. Some chado instances may choose to simply
remove the feature altogether, others may choose to keep an obsolete
row in the table.

=head2 timeaccessioned

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

For handling object
accession or modification timestamps (as opposed to database auditing data,
handled elsewhere). The expectation is that these fields would be
available to software interacting with chado.

=head2 timelastmodified

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

For handling object
accession or modification timestamps (as opposed to database auditing data,
handled elsewhere). The expectation is that these fields would be
available to software interacting with chado.

=cut

__PACKAGE__->add_columns(
  "feature_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_feature_id_seq",
  },
  "dbxref_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "organism_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "uniquename",
  { data_type => "text", is_nullable => 0 },
  "residues",
  { data_type => "text", is_nullable => 1 },
  "seqlen",
  { data_type => "integer", is_nullable => 1 },
  "md5checksum",
  { data_type => "char", is_nullable => 1, size => 32 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_analysis",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_obsolete",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "timeaccessioned",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "timelastmodified",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("feature_id");
__PACKAGE__->add_unique_constraint("feature_c1", ["organism_id", "uniquename", "type_id"]);

=head1 RELATIONS

=head2 analysisfeatures

Type: has_many

Related object: L<PomCur::ChadoDB::Analysisfeature>

=cut

__PACKAGE__->has_many(
  "analysisfeatures",
  "PomCur::ChadoDB::Analysisfeature",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_features

Type: has_many

Related object: L<PomCur::ChadoDB::CellLineFeature>

=cut

__PACKAGE__->has_many(
  "cell_line_features",
  "PomCur::ChadoDB::CellLineFeature",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 elements

Type: has_many

Related object: L<PomCur::ChadoDB::Element>

=cut

__PACKAGE__->has_many(
  "elements",
  "PomCur::ChadoDB::Element",
  { "foreign.feature_id" => "self.feature_id" },
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

=head2 dbxref

Type: belongs_to

Related object: L<PomCur::ChadoDB::Dbxref>

=cut

__PACKAGE__->belongs_to(
  "dbxref",
  "PomCur::ChadoDB::Dbxref",
  { dbxref_id => "dbxref_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 organism

Type: belongs_to

Related object: L<PomCur::ChadoDB::Organism>

=cut

__PACKAGE__->belongs_to(
  "organism",
  "PomCur::ChadoDB::Organism",
  { organism_id => "organism_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 feature_cvterms

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureCvterm>

=cut

__PACKAGE__->has_many(
  "feature_cvterms",
  "PomCur::ChadoDB::FeatureCvterm",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_dbxrefs

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureDbxref>

=cut

__PACKAGE__->has_many(
  "feature_dbxrefs",
  "PomCur::ChadoDB::FeatureDbxref",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_expressions

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureExpression>

=cut

__PACKAGE__->has_many(
  "feature_expressions",
  "PomCur::ChadoDB::FeatureExpression",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_genotype_features

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureGenotype>

=cut

__PACKAGE__->has_many(
  "feature_genotype_features",
  "PomCur::ChadoDB::FeatureGenotype",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_genotype_chromosomes

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureGenotype>

=cut

__PACKAGE__->has_many(
  "feature_genotype_chromosomes",
  "PomCur::ChadoDB::FeatureGenotype",
  { "foreign.chromosome_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureloc_features

Type: has_many

Related object: L<PomCur::ChadoDB::Featureloc>

=cut

__PACKAGE__->has_many(
  "featureloc_features",
  "PomCur::ChadoDB::Featureloc",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureloc_srcfeatures

Type: has_many

Related object: L<PomCur::ChadoDB::Featureloc>

=cut

__PACKAGE__->has_many(
  "featureloc_srcfeatures",
  "PomCur::ChadoDB::Featureloc",
  { "foreign.srcfeature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_phenotypes

Type: has_many

Related object: L<PomCur::ChadoDB::FeaturePhenotype>

=cut

__PACKAGE__->has_many(
  "feature_phenotypes",
  "PomCur::ChadoDB::FeaturePhenotype",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurepos_feature

Type: has_many

Related object: L<PomCur::ChadoDB::Featurepo>

=cut

__PACKAGE__->has_many(
  "featurepos_feature",
  "PomCur::ChadoDB::Featurepo",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurepos_map_features

Type: has_many

Related object: L<PomCur::ChadoDB::Featurepo>

=cut

__PACKAGE__->has_many(
  "featurepos_map_features",
  "PomCur::ChadoDB::Featurepo",
  { "foreign.map_feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureprops

Type: has_many

Related object: L<PomCur::ChadoDB::Featureprop>

=cut

__PACKAGE__->has_many(
  "featureprops",
  "PomCur::ChadoDB::Featureprop",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::FeaturePub>

=cut

__PACKAGE__->has_many(
  "feature_pubs",
  "PomCur::ChadoDB::FeaturePub",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurerange_leftendfs

Type: has_many

Related object: L<PomCur::ChadoDB::Featurerange>

=cut

__PACKAGE__->has_many(
  "featurerange_leftendfs",
  "PomCur::ChadoDB::Featurerange",
  { "foreign.leftendf_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurerange_rightstartfs

Type: has_many

Related object: L<PomCur::ChadoDB::Featurerange>

=cut

__PACKAGE__->has_many(
  "featurerange_rightstartfs",
  "PomCur::ChadoDB::Featurerange",
  { "foreign.rightstartf_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurerange_rightendfs

Type: has_many

Related object: L<PomCur::ChadoDB::Featurerange>

=cut

__PACKAGE__->has_many(
  "featurerange_rightendfs",
  "PomCur::ChadoDB::Featurerange",
  { "foreign.rightendf_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurerange_leftstartfs

Type: has_many

Related object: L<PomCur::ChadoDB::Featurerange>

=cut

__PACKAGE__->has_many(
  "featurerange_leftstartfs",
  "PomCur::ChadoDB::Featurerange",
  { "foreign.leftstartf_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurerange_features

Type: has_many

Related object: L<PomCur::ChadoDB::Featurerange>

=cut

__PACKAGE__->has_many(
  "featurerange_features",
  "PomCur::ChadoDB::Featurerange",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationship_subjects

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureRelationship>

=cut

__PACKAGE__->has_many(
  "feature_relationship_subjects",
  "PomCur::ChadoDB::FeatureRelationship",
  { "foreign.subject_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationship_objects

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureRelationship>

=cut

__PACKAGE__->has_many(
  "feature_relationship_objects",
  "PomCur::ChadoDB::FeatureRelationship",
  { "foreign.object_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_synonyms

Type: has_many

Related object: L<PomCur::ChadoDB::FeatureSynonym>

=cut

__PACKAGE__->has_many(
  "feature_synonyms",
  "PomCur::ChadoDB::FeatureSynonym",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 library_features

Type: has_many

Related object: L<PomCur::ChadoDB::LibraryFeature>

=cut

__PACKAGE__->has_many(
  "library_features",
  "PomCur::ChadoDB::LibraryFeature",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylonodes

Type: has_many

Related object: L<PomCur::ChadoDB::Phylonode>

=cut

__PACKAGE__->has_many(
  "phylonodes",
  "PomCur::ChadoDB::Phylonode",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 studyprop_features

Type: has_many

Related object: L<PomCur::ChadoDB::StudypropFeature>

=cut

__PACKAGE__->has_many(
  "studyprop_features",
  "PomCur::ChadoDB::StudypropFeature",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ryJUapFFhZDwWRh3b6Ml4Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
