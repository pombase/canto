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

  data_type: 'varchar'
  is_nullable: 0
  size: 1024

=head2 definition

  data_type: 'text'
  is_nullable: 1

=head2 is_obsolete

  data_type: 'int'
  default_value: 0
  is_nullable: 0

=head2 is_relationshiptype

  data_type: 'int'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "cvterm_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "cv_id",
  { data_type => "int", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 1024 },
  "definition",
  { data_type => "text", is_nullable => 1 },
  "is_obsolete",
  { data_type => "int", default_value => 0, is_nullable => 0 },
  "is_relationshiptype",
  { data_type => "int", default_value => 0, is_nullable => 0 },
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

=head2 gene_synonyms

Type: has_many

Related object: L<PomCur::TrackDB::GeneSynonym>

=cut

__PACKAGE__->has_many(
  "gene_synonyms",
  "PomCur::TrackDB::GeneSynonym",
  { "foreign.synonym_type" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-09-30 16:18:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3nQSW+UJD3ARtiejdHlA5w


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
