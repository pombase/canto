use utf8;
package Canto::CursDB::Gene;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::Gene

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

Related object: L<Canto::CursDB::Allele>

=cut

__PACKAGE__->has_many(
  "alleles",
  "Canto::CursDB::Allele",
  { "foreign.gene" => "self.gene_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 gene_annotations

Type: has_many

Related object: L<Canto::CursDB::GeneAnnotation>

=cut

__PACKAGE__->has_many(
  "gene_annotations",
  "Canto::CursDB::GeneAnnotation",
  { "foreign.gene" => "self.gene_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organism

Type: belongs_to

Related object: L<Canto::CursDB::Organism>

=cut

__PACKAGE__->belongs_to(
  "organism",
  "Canto::CursDB::Organism",
  { organism_id => "organism" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2018-05-02 10:30:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:O2vcN5tZ2U8LP7XhLqb/lA

=head2 feature_id

 Usage   : $gene->feature_id()
 Function: Return the gene_id of this gene.  This is an alias for gene_id()
           that exists to make gene and genotype handling easier.

=cut

sub feature_id
{
  my $self = shift;

  return $self->gene_id();
}

=head2 feature_type

 Usage   : $gene->feature_type();
 Function: Return 'gene'.  This exists to make gene and genotype handling
           easier.

=cut

sub feature_type
{
  return 'gene';
}

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
  my $all_annotations = shift // 0;
  my $remove_annotations = shift // 0;
  my $include_with_annotations = shift // 1;

  my %ids = ();

  if ($all_annotations) {
    my $rs = $self->direct_annotations()->get_column('annotation_id');
    while (defined (my $annotation_id = $rs->next())) {
      $ids{$annotation_id} = 1;
    }
  }

  my $schema = $self->result_source()->schema();
  my $rs = $schema->resultset("Annotation");

  while (defined (my $annotation = $rs->next())) {
    if (!exists $ids{$annotation->annotation_id()}) {
      my $data = $annotation->data();
      my $with_gene = $data->{with_gene};

      if ($include_with_annotations &&
          defined $with_gene && $with_gene eq $self->primary_identifier()) {
        $ids{$annotation->annotation_id()} = 1;
      }
    }
  }

  my $return_rs = $schema->resultset("Annotation")
    ->search({ annotation_id => { -in => [keys %ids] }});

  if ($remove_annotations) {
    while (defined (my $annotation = $return_rs->next())) {
      # delete one-by-one so that gene_annotation rows are deleted too
      $annotation->delete();
    }
    return undef;
  } else {
    return $return_rs;
  }
}

=head2 indirect_annotations

 Usage   : my @annotations = $gene->indirect_annotations();
 Function: Return those annotations that reference this Gene in data field of
           the Annotations (eg. the "with_gene" field or as an interactor)
 Args    : None

=cut
sub indirect_annotations
{
  my $self = shift;

  return $self->_get_indirect_annotations(0);
}

=head2 all_annotations

 Usage   : my @annotations =
             $gene->all_annotations(include_with => 1);
 Function: Return those annotations are related to this Gene via the
           gene_annotations tables or that reference this Gene in data
           field of the Annotation (eg. the "with_gene" field or as an
           interactor)
 Args    : include_with - if true, annotations that reference this
           gene via a "with" field will be included in the results

=cut
sub all_annotations
{
  my $self = shift;
  my %args = @_;

  my $include_with = $args{include_with} // 0;

  return $self->_get_indirect_annotations(1, 0, $include_with);
}

=head2 genotypes

 Usage   : my $genotypes_rs = $self->genotypes();
 Function:
 Args    :
 Returns :

=cut
sub genotypes
{
  my $self = shift;

  return $self->search_related_rs('alleles')->search_related_rs('allele_genotypes')
    ->search_related_rs('genotype');
}

sub delete
{
  my $self = shift;

  map {
    my $allele = $_;
    my $allele_genotype_rs =
      $allele->allele_genotypes()->search({}, { prefetch => 'genotype' });

    while (defined (my $allele_genotype = $allele_genotype_rs->next())) {
      my $genotype = $allele_genotype->genotype();
      my $genotype_annotation_rs =
        $genotype->genotype_annotations()
          ->search({}, { prefetch => 'annotation' });

      while (defined (my $genotype_anno = $genotype_annotation_rs->next())) {
        my $annotation = $genotype_anno->annotation();
        $genotype_anno->delete();
        $annotation->delete();
      }

      $allele_genotype->delete();
      $genotype->delete();
    };
    $allele->search_related('allelesynonyms')->delete();
    $allele->delete();
  } $self->alleles();

  $self->_get_indirect_annotations(1, 1);

  $self->SUPER::delete();
}


__PACKAGE__->meta->make_immutable;

1;
