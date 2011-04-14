package PomCur::CursDB::Gene;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::CursDB::Gene

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

=head2 primary_name

  data_type: 'text'
  is_nullable: 1

=head2 product

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
  "primary_name",
  { data_type => "text", is_nullable => 1 },
  "product",
  { data_type => "text", is_nullable => 1 },
  "organism",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("gene_id");
__PACKAGE__->add_unique_constraint("primary_identifier_unique", ["primary_identifier"]);

=head1 RELATIONS

=head2 organism

Type: belongs_to

Related object: L<PomCur::CursDB::Organism>

=cut

__PACKAGE__->belongs_to(
  "organism",
  "PomCur::CursDB::Organism",
  { organism_id => "organism" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 genesynonyms

Type: has_many

Related object: L<PomCur::CursDB::Genesynonym>

=cut

__PACKAGE__->has_many(
  "genesynonyms",
  "PomCur::CursDB::Genesynonym",
  { "foreign.gene_id" => "self.gene_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 gene_annotations

Type: has_many

Related object: L<PomCur::CursDB::GeneAnnotation>

=cut

__PACKAGE__->has_many(
  "gene_annotations",
  "PomCur::CursDB::GeneAnnotation",
  { "foreign.gene" => "self.gene_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-04-08 13:29:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:a/kSfOpENIAOvaVK/76BjA

=head2 direct_annotations

 Usage   : my $annotations_rs = $gene->direct_annotations();
 Function: Return the Annotation object related to this gene via the
           gene_annotations table
 Args    : None
 Returns : An Annotation ResultSet

=cut
__PACKAGE__->many_to_many('direct_annotations' => 'gene_annotations',
                          'annotation');

sub _get_indirect_annotations
{
  my $self = shift;
  my $all_annotations = shift;

  my @ret;
  my %ids = ();

  if ($all_annotations) {
    @ret = $self->direct_annotations();

    for my $annotation (@ret) {
      $ids{$annotation->annotation_id()} = 1;
    }
  } else {
    @ret = ();
  }

  my $schema = $self->result_source()->schema();

  my $rs = $schema->resultset("Annotation");

  while (defined (my $annotation = $rs->next())) {
    if (!exists $ids{$annotation->annotation_id()}) {
      my $data = $annotation->data();
      my $with_gene = $data->{with_gene};

      if (defined $with_gene && $with_gene eq $self->primary_identifier()) {
        push @ret, $annotation;
        $ids{$annotation->annotation_id()} = 1;
      } else {
        my $interacting_genes = $annotation->data()->{interacting_genes};

        if (defined $interacting_genes) {
          my @interacting_genes = @$interacting_genes;

          for my $interacting_gene (@interacting_genes) {
            my $interacting_gene_identifier =
              $interacting_gene->{primary_identifier};
            if ($interacting_gene_identifier eq $self->primary_identifier()) {
              push @ret, $annotation;
              $ids{$annotation->annotation_id()} = 1;
              last;
            }
          }
        }
      }
    }
  }

  return @ret;
}

=head2 indirect_annotations

 Usage   : my @annotations = $gene->indirect_annotations();
 Function: Return those annotations that reference this Gene in data field of
           the Annotations (eg. the "with_gene" field)
 Args    : None

=cut
sub indirect_annotations
{
  my $self = shift;

  return $self->_get_indirect_annotations(0);
}

=head2 all_annotations

 Usage   : my @annotations = $gene->all_annotations();
 Function: Return those annotations are related to this Gene via the
           gene_annotations tables or that reference this Gene in data
           field of the Annotation (eg. the "with_gene" field)
 Args    : None

=cut
sub all_annotations
{
  my $self = shift;

  return $self->_get_indirect_annotations(1);
}

sub delete
{
  my $self = shift;

  my @annotations = $self->all_annotations();
  map { $_->gene_annotations()->delete() } @annotations;
  map { $_->delete() } @annotations;

  $self->genesynonyms()->delete();

  $self->SUPER::delete();
}

use Moose;

with 'PomCur::Role::GeneNames';


__PACKAGE__->meta->make_immutable;

1;
