package PomCur::TrackDB::Cvterm;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::TrackDB::Cvterm

=cut

__PACKAGE__->table("cvterm");

=head1 ACCESSORS

=head2 cvterm_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 cv_id

  data_type: 'int'
  is_foreign_key: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 dbxref_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 definition

  data_type: 'text'
  is_nullable: 1

=head2 is_obsolete

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 is_relationshiptype

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "cvterm_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "cv_id",
  { data_type => "int", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "dbxref_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "definition",
  { data_type => "text", is_nullable => 1 },
  "is_obsolete",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "is_relationshiptype",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("cvterm_id");

=head1 RELATIONS

=head2 pub_triage_statuses

Type: has_many

Related object: L<PomCur::TrackDB::Pub>

=cut

__PACKAGE__->has_many(
  "pub_triage_statuses",
  "PomCur::TrackDB::Pub",
  { "foreign.triage_status_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_types

Type: has_many

Related object: L<PomCur::TrackDB::Pub>

=cut

__PACKAGE__->has_many(
  "pub_types",
  "PomCur::TrackDB::Pub",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubprops

Type: has_many

Related object: L<PomCur::TrackDB::Pubprop>

=cut

__PACKAGE__->has_many(
  "pubprops",
  "PomCur::TrackDB::Pubprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_curation_statuses

Type: has_many

Related object: L<PomCur::TrackDB::PubCurationStatus>

=cut

__PACKAGE__->has_many(
  "pub_curation_statuses",
  "PomCur::TrackDB::PubCurationStatus",
  { "foreign.status_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 dbxref

Type: belongs_to

Related object: L<PomCur::TrackDB::Dbxref>

=cut

__PACKAGE__->belongs_to(
  "dbxref",
  "PomCur::TrackDB::Dbxref",
  { dbxref_id => "dbxref_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 cv

Type: belongs_to

Related object: L<PomCur::TrackDB::Cv>

=cut

__PACKAGE__->belongs_to(
  "cv",
  "PomCur::TrackDB::Cv",
  { cv_id => "cv_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 cvtermsynonym_types

Type: has_many

Related object: L<PomCur::TrackDB::Cvtermsynonym>

=cut

__PACKAGE__->has_many(
  "cvtermsynonym_types",
  "PomCur::TrackDB::Cvtermsynonym",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermsynonym_cvterms

Type: has_many

Related object: L<PomCur::TrackDB::Cvtermsynonym>

=cut

__PACKAGE__->has_many(
  "cvtermsynonym_cvterms",
  "PomCur::TrackDB::Cvtermsynonym",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_objects

Type: has_many

Related object: L<PomCur::TrackDB::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_objects",
  "PomCur::TrackDB::CvtermRelationship",
  { "foreign.object_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_subjects

Type: has_many

Related object: L<PomCur::TrackDB::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_subjects",
  "PomCur::TrackDB::CvtermRelationship",
  { "foreign.subject_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_types

Type: has_many

Related object: L<PomCur::TrackDB::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_types",
  "PomCur::TrackDB::CvtermRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermprop_types

Type: has_many

Related object: L<PomCur::TrackDB::Cvtermprop>

=cut

__PACKAGE__->has_many(
  "cvtermprop_types",
  "PomCur::TrackDB::Cvtermprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermprop_cvterms

Type: has_many

Related object: L<PomCur::TrackDB::Cvtermprop>

=cut

__PACKAGE__->has_many(
  "cvtermprop_cvterms",
  "PomCur::TrackDB::Cvtermprop",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organismprops

Type: has_many

Related object: L<PomCur::TrackDB::Organismprop>

=cut

__PACKAGE__->has_many(
  "organismprops",
  "PomCur::TrackDB::Organismprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 people

Type: has_many

Related object: L<PomCur::TrackDB::Person>

=cut

__PACKAGE__->has_many(
  "people",
  "PomCur::TrackDB::Person",
  { "foreign.role" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-03-23 19:13:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:I+2ulK9Zg5pmyk7jntCshQ

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
