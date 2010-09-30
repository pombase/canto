package PomCur::TrackDB::GeneSynonym;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::TrackDB::GeneSynonym

=cut

__PACKAGE__->table("gene_synonym");

=head1 ACCESSORS

=head2 gene_synonym_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 identifier

  data_type: 'text'
  is_nullable: 0

=head2 synonym_type

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "gene_synonym_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "identifier",
  { data_type => "text", is_nullable => 0 },
  "synonym_type",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("gene_synonym_id");

=head1 RELATIONS

=head2 synonym_type

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "synonym_type",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "synonym_type" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-09-30 16:18:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qaWFdoo23SENQwW6SrXlBA


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
