package Canto::ChadoDB::Dbxref;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::Dbxref

=head1 DESCRIPTION

A unique, global, public, stable identifier. Not necessarily an external reference - can reference data items inside the particular chado instance being used. Typically a row in a table can be uniquely identified with a primary identifier (called dbxref_id); a table may also have secondary identifiers (in a linking table <T>_dbxref). A dbxref is generally written as <DB>:<ACCESSION> or as <DB>:<ACCESSION>:<VERSION>.

=cut

__PACKAGE__->table("dbxref");

=head1 ACCESSORS

=head2 dbxref_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'dbxref_dbxref_id_seq'

=head2 db_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 accession

  data_type: 'varchar'
  is_nullable: 0
  size: 255

The local part of the identifier. Guaranteed by the db authority to be unique for that db.

=head2 version

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "dbxref_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dbxref_dbxref_id_seq",
  },
  "db_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "accession",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "version",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
  "description",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("dbxref_id");
__PACKAGE__->add_unique_constraint("dbxref_c1", ["db_id", "accession", "version"]);

=head1 RELATIONS

=head2 arraydesigns

Type: has_many

Related object: L<Canto::ChadoDB::Arraydesign>

=cut

__PACKAGE__->has_many(
  "arraydesigns",
  "Canto::ChadoDB::Arraydesign",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 assays

Type: has_many

Related object: L<Canto::ChadoDB::Assay>

=cut

__PACKAGE__->has_many(
  "assays",
  "Canto::ChadoDB::Assay",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 biomaterials

Type: has_many

Related object: L<Canto::ChadoDB::Biomaterial>

=cut

__PACKAGE__->has_many(
  "biomaterials",
  "Canto::ChadoDB::Biomaterial",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 biomaterial_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::BiomaterialDbxref>

=cut

__PACKAGE__->has_many(
  "biomaterial_dbxrefs",
  "Canto::ChadoDB::BiomaterialDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cell_line_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::CellLineDbxref>

=cut

__PACKAGE__->has_many(
  "cell_line_dbxrefs",
  "Canto::ChadoDB::CellLineDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm

Type: might_have

Related object: L<Canto::ChadoDB::Cvterm>

=cut

__PACKAGE__->might_have(
  "cvterm",
  "Canto::ChadoDB::Cvterm",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::CvtermDbxref>

=cut

__PACKAGE__->has_many(
  "cvterm_dbxrefs",
  "Canto::ChadoDB::CvtermDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 db

Type: belongs_to

Related object: L<Canto::ChadoDB::Db>

=cut

__PACKAGE__->belongs_to(
  "db",
  "Canto::ChadoDB::Db",
  { db_id => "db_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 dbxrefprops

Type: has_many

Related object: L<Canto::ChadoDB::Dbxrefprop>

=cut

__PACKAGE__->has_many(
  "dbxrefprops",
  "Canto::ChadoDB::Dbxrefprop",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 elements

Type: has_many

Related object: L<Canto::ChadoDB::Element>

=cut

__PACKAGE__->has_many(
  "elements",
  "Canto::ChadoDB::Element",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 features

Type: has_many

Related object: L<Canto::ChadoDB::Feature>

=cut

__PACKAGE__->has_many(
  "features",
  "Canto::ChadoDB::Feature",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvterm_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::FeatureCvtermDbxref>

=cut

__PACKAGE__->has_many(
  "feature_cvterm_dbxrefs",
  "Canto::ChadoDB::FeatureCvtermDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::FeatureDbxref>

=cut

__PACKAGE__->has_many(
  "feature_dbxrefs",
  "Canto::ChadoDB::FeatureDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 library_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::LibraryDbxref>

=cut

__PACKAGE__->has_many(
  "library_dbxrefs",
  "Canto::ChadoDB::LibraryDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_experiment_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::NdExperimentDbxref>

=cut

__PACKAGE__->has_many(
  "nd_experiment_dbxrefs",
  "Canto::ChadoDB::NdExperimentDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nd_experiment_stock_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::NdExperimentStockDbxref>

=cut

__PACKAGE__->has_many(
  "nd_experiment_stock_dbxrefs",
  "Canto::ChadoDB::NdExperimentStockDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organism_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::OrganismDbxref>

=cut

__PACKAGE__->has_many(
  "organism_dbxrefs",
  "Canto::ChadoDB::OrganismDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylonode_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::PhylonodeDbxref>

=cut

__PACKAGE__->has_many(
  "phylonode_dbxrefs",
  "Canto::ChadoDB::PhylonodeDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 phylotrees

Type: has_many

Related object: L<Canto::ChadoDB::Phylotree>

=cut

__PACKAGE__->has_many(
  "phylotrees",
  "Canto::ChadoDB::Phylotree",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 protocols

Type: has_many

Related object: L<Canto::ChadoDB::Protocol>

=cut

__PACKAGE__->has_many(
  "protocols",
  "Canto::ChadoDB::Protocol",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::PubDbxref>

=cut

__PACKAGE__->has_many(
  "pub_dbxrefs",
  "Canto::ChadoDB::PubDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stocks

Type: has_many

Related object: L<Canto::ChadoDB::Stock>

=cut

__PACKAGE__->has_many(
  "stocks",
  "Canto::ChadoDB::Stock",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stock_dbxrefs

Type: has_many

Related object: L<Canto::ChadoDB::StockDbxref>

=cut

__PACKAGE__->has_many(
  "stock_dbxrefs",
  "Canto::ChadoDB::StockDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 studies

Type: has_many

Related object: L<Canto::ChadoDB::Study>

=cut

__PACKAGE__->has_many(
  "studies",
  "Canto::ChadoDB::Study",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GK/B7Vcqhw3urXjjkMPuQA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
