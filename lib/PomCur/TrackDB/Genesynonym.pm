package PomCur::TrackDB::Genesynonym;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::TrackDB::Genesynonym

=cut

__PACKAGE__->table("genesynonym");

=head1 ACCESSORS

=head2 genesynonym_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 gene

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 identifier

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "genesynonym_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "gene",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "identifier",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("genesynonym_id");

=head1 RELATIONS

=head2 gene

Type: belongs_to

Related object: L<PomCur::TrackDB::Gene>

=cut

__PACKAGE__->belongs_to(
  "gene",
  "PomCur::TrackDB::Gene",
  { gene_id => "gene" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-11-03 12:15:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:N+FFvDd2kzKG63vGqqRJ8A


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
