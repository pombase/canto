package Canto::ChadoDB::Synonym;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::Synonym

=head1 DESCRIPTION

A synonym for a feature. One feature can have multiple synonyms, and the same synonym can apply to multiple features.

=cut

__PACKAGE__->table("synonym");

=head1 ACCESSORS

=head2 synonym_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'synonym_synonym_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

The synonym itself. Should be human-readable machine-searchable ascii text.

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Types would be symbol and fullname for now.

=head2 synonym_sgml

  data_type: 'varchar'
  is_nullable: 0
  size: 255

The fully specified synonym, with any non-ascii characters encoded in SGML.

=cut

__PACKAGE__->add_columns(
  "synonym_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "synonym_synonym_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "synonym_sgml",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("synonym_id");
__PACKAGE__->add_unique_constraint("synonym_c1", ["name", "type_id"]);

=head1 RELATIONS

=head2 cell_line_synonyms

Type: has_many

Related object: L<Canto::ChadoDB::CellLineSynonym>

=cut

__PACKAGE__->has_many(
  "cell_line_synonyms",
  "Canto::ChadoDB::CellLineSynonym",
  { "foreign.synonym_id" => "self.synonym_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_synonyms

Type: has_many

Related object: L<Canto::ChadoDB::FeatureSynonym>

=cut

__PACKAGE__->has_many(
  "feature_synonyms",
  "Canto::ChadoDB::FeatureSynonym",
  { "foreign.synonym_id" => "self.synonym_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 library_synonyms

Type: has_many

Related object: L<Canto::ChadoDB::LibrarySynonym>

=cut

__PACKAGE__->has_many(
  "library_synonyms",
  "Canto::ChadoDB::LibrarySynonym",
  { "foreign.synonym_id" => "self.synonym_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 type

Type: belongs_to

Related object: L<Canto::ChadoDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "Canto::ChadoDB::Cvterm",
  { cvterm_id => "type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rmCRuYvnU/W3JgXGmawgLQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
