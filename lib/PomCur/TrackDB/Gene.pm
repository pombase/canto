use utf8;
package PomCur::TrackDB::Gene;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PomCur::TrackDB::Gene

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<gene>

=cut

__PACKAGE__->table("gene");

=head1 ACCESSORS

=head2 gene_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 primary_identifier

  data_type: 'text'
  is_nullable: 0

=head2 product

  data_type: 'text'
  is_nullable: 1

=head2 primary_name

  data_type: 'text'
  is_nullable: 1

=head2 organism

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "gene_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "primary_identifier",
  { data_type => "text", is_nullable => 0 },
  "product",
  { data_type => "text", is_nullable => 1 },
  "primary_name",
  { data_type => "text", is_nullable => 1 },
  "organism",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</gene_id>

=back

=cut

__PACKAGE__->set_primary_key("gene_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<primary_identifier_unique>

=over 4

=item * L</primary_identifier>

=back

=cut

__PACKAGE__->add_unique_constraint("primary_identifier_unique", ["primary_identifier"]);

=head1 RELATIONS

=head2 alleles

Type: has_many

Related object: L<PomCur::TrackDB::Allele>

=cut

__PACKAGE__->has_many(
  "alleles",
  "PomCur::TrackDB::Allele",
  { "foreign.gene" => "self.gene_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 genesynonyms

Type: has_many

Related object: L<PomCur::TrackDB::Genesynonym>

=cut

__PACKAGE__->has_many(
  "genesynonyms",
  "PomCur::TrackDB::Genesynonym",
  { "foreign.gene" => "self.gene_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organism

Type: belongs_to

Related object: L<PomCur::TrackDB::Organism>

=cut

__PACKAGE__->belongs_to(
  "organism",
  "PomCur::TrackDB::Organism",
  { organism_id => "organism" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-03-11 23:28:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ytr880f3vid8gOB5TrzGZQ

use Moose;

with 'PomCur::Role::GeneNames';

# alias for Chado compatibility
sub synonyms
{
  my $self = shift;

  return $self->genesynonyms();
}

# alias for Chado compatibility
sub feature_id
{
  my $self = shift;

  return $self->gene_id();
}


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
