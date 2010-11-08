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
);
__PACKAGE__->set_primary_key("cvterm_id");

=head1 RELATIONS

=head2 pubs

Type: has_many

Related object: L<PomCur::TrackDB::Pub>

=cut

__PACKAGE__->has_many(
  "pubs",
  "PomCur::TrackDB::Pub",
  { "foreign.type_id" => "self.cvterm_id" },
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

=head2 pub_statuses

Type: has_many

Related object: L<PomCur::TrackDB::PubStatus>

=cut

__PACKAGE__->has_many(
  "pub_statuses",
  "PomCur::TrackDB::PubStatus",
  { "foreign.status" => "self.cvterm_id" },
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


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-11-05 19:49:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fkfo9cnkbKSLgFOHLrGp/g

sub db_accession
{
  my $cvterm = shift;

  my $dbxref = $cvterm->dbxref();
  my $db = $dbxref->db();

  return $db->name() . ':' . $dbxref->accession();
}

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
