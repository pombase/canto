package PomCur::Curs::Utils;

=head1 NAME

PomCur::Curs::Utils - Utilities for Curs code

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Curs::Utils

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;

sub _make_ontology_annotation
{
  my $config = shift;
  my $schema = shift;
  my $annotation = shift;
  my $ontology_lookup = shift;
  my $gene = shift;
  my $gene_synonyms_string = shift;

  my $data = $annotation->data();
  my $term_ontid = $data->{term_ontid};
  die "no term_ontid for annotation"
    unless defined $term_ontid and length $term_ontid > 0;

  my $annotation_type = $annotation->type();

  my %annotation_types_config = %{$config->{annotation_types}};
  my $annotation_type_config = $annotation_types_config{$annotation_type};
  my $annotation_type_display_name = $annotation_type_config->{display_name};
  my $annotation_type_abbreviation = $annotation_type_config->{abbreviation};

  my %evidence_types = %{$config->{evidence_types}};

  my $uniquename = $annotation->pub()->uniquename();
  my $result =
    $ontology_lookup->lookup(ontology_name => $annotation_type,
                              search_string => $term_ontid);

  my $term_name = $result->[0]->{name};
  my $evidence_code = $data->{evidence_code};
  my $with_gene_identifier = $data->{with_gene};

  my $evidence_type_name;
  my $needs_with;
  if (defined $evidence_code) {
    $evidence_type_name = $evidence_types{$evidence_code}->{name};
    $needs_with = $evidence_types{$evidence_code}->{with_gene};
  } else {
    $evidence_type_name = undef;
    $needs_with = 0;
  }

  my $with_gene;
  my $with_gene_display_name;

  if ($with_gene_identifier) {
    $with_gene = $schema->find_with_type('Gene',
                                         { primary_identifier =>
                                             $with_gene_identifier });
    $with_gene_display_name = $with_gene->display_name()
  }

  (my $short_date = $annotation->creation_date()) =~ s/-//g;

  my $completed = defined $evidence_code &&
    (!$needs_with || defined $with_gene_identifier);

  return {
    gene_identifier => $gene->primary_identifier(),
    gene_name => $gene->primary_name() || '',
    gene_name_or_identifier =>
      $gene->primary_name() || $gene->primary_identifier(),
    gene_product => $gene->product() // '',
    gene_synonyms_string => $gene_synonyms_string,
    qualifier => '',
    annotation_type => $annotation_type,
    annotation_type_display_name => $annotation_type_display_name,
    annotation_type_abbreviation => $annotation_type_abbreviation // '',
    annotation_id => $annotation->annotation_id(),
    uniquename => $uniquename,
    term_ontid => $term_ontid,
    term_name => $term_name,
    evidence_code => $evidence_code,
    evidence_type_name => $evidence_type_name,
    creation_date => $annotation->creation_date(),
    creation_date_short => $short_date,
    term_suggestion => $annotation->data()->{term_suggestion},
    needs_with => $needs_with,
    with_or_from_identifier => $with_gene_identifier,
    with_or_from_display_name => $with_gene_display_name,
    taxonid => $gene->organism()->taxonid(),
    completed => $completed,
  };
}

sub _make_interaction_annotation
{
  my $config = shift;
  my $schema = shift;
  my $annotation = shift;
  my $gene = shift;

  my $data = $annotation->data();
  my $evidence_code = $data->{evidence_code};
  my $annotation_type = $annotation->type();

  my %annotation_types_config = %{$config->{annotation_types}};
  my $annotation_type_config = $annotation_types_config{$annotation_type};
  my $annotation_type_display_name = $annotation_type_config->{display_name};

  my $pub_uniquename = $annotation->pub()->uniquename();

  my @interacting_genes = @{$data->{interacting_genes}};

  return map {
    my $interacting_gene_info = $_;
    my $interacting_gene_primary_identifier =
      $interacting_gene_info->{primary_identifier};
    my $interacting_gene_display_name =
      $schema->find_with_type('Gene',
                              { primary_identifier =>
                                  $interacting_gene_primary_identifier})
        ->display_name();
    my $entry =
          {
            gene_identifier => $gene->primary_identifier(),
            gene_display_name => $gene->display_name(),
            gene_taxonid => $gene->organism()->taxonid(),
            publication_uniquename => $pub_uniquename,
            evidence_code => $evidence_code,
            interacting_gene_identifier =>
              $interacting_gene_primary_identifier,
            interacting_gene_display_name =>
              $interacting_gene_display_name,
            interacting_gene_taxonid =>
              $interacting_gene_info->{organism_taxon}
                // $gene->organism()->taxonid(),
            score => '',
            phenotypes => '',
            comment => '',
            completed => 1,
            annotation_id => $annotation->annotation_id(),
          };
    $entry;
  } @interacting_genes;
};

=head2 get_annotation_table

 Usage   : my @annotations =
             PomCur::Curs::Utils::get_annotation_table($config, $schema,
                                                       $annotation_type_name);
 Function: Return a table of the current annotations
 Args    : $config - the PomCur::Config object
           $schema - a PomCur::CursDB object
           $annotation_type_name - the type of annotation to show (eg.
                                   biological_process, phenotype)
           $annotation - the annotation to show; if set only the row containing
                         this annotation will be returned; optional
 Returns : ($completed_count, $table)
           where:
             $completed_count - a count of the annotations that are incomplete
                because they need an evidence code or a with field, etc.
             $table - an array of hashes containing the annotation in the form:
           [ { gene_identifier => 'SPCC1739.11c', gene_name => 'cdc11',
               annotation_type => 'molecular_function',
               annotation_id => 1234, term_ontid => 'GO:0055085',
               term_name => 'transmembrane transport',
               evidence_code => 'IDA',
               evidence_type_name => 'Inferred from direct assay' },
             { gene_identifier => '...', ... }, ]
           where annotation_id is the id of the Annotation object for this
           annotation

=cut

sub get_annotation_table
{
  my $config = shift;
  my $schema = shift;
  my $annotation_type_name = shift;
  my $constrain_annotations = shift;

  my @annotations = ();

  my %annotation_types_config = %{$config->{annotation_types}};
  my $annotation_type_config = $annotation_types_config{$annotation_type_name};
  my $annotation_type_category = $annotation_type_config->{category};

  my $ontology_lookup =
    PomCur::Track::get_adaptor($config, 'ontology');

  my $gene_rs = $schema->resultset('Gene');

  my $completed_count = 0;

  my %constraints = (
    type => $annotation_type_name,
  );

  if ($constrain_annotations) {
    if (ref $constrain_annotations eq 'ARRAY') {
      my @constrain_annotations = @$constrain_annotations;
      $constraints{annotation_id} = {
        -in => [map { $_->annotation_id() } @constrain_annotations]
      };
    } else {
      $constraints{annotation_id} = $constrain_annotations->annotation_id();
    }
  }

  my %options = ( order_by => 'annotation_id' );

  while (defined (my $gene = $gene_rs->next())) {
    my $an_rs =
      $gene->direct_annotations()->search({ %constraints }, { %options });

    my $gene_synonyms_string =
      join '|', map { $_->identifier() } $gene->genesynonyms();

    while (defined (my $annotation = $an_rs->next())) {
      my @entries;
      if ($annotation_type_category eq 'ontology') {
        @entries = (_make_ontology_annotation($config, $schema, $annotation,
                                              $ontology_lookup,
                                              $gene, $gene_synonyms_string));
      } else {
        if ($annotation_type_category eq 'interaction') {
          @entries = _make_interaction_annotation($config, $schema, $annotation,
                                                  $gene);
        } else {
          die "unknown annotation type category: $annotation_type_category\n";
        }
      }
      push @annotations, @entries;
      map { $completed_count++ if $_->{completed} } @entries;
    }
  }

  my $ontology_column_names =
    [qw(db gene_identifier gene_name_or_identifier
        qualifier term_ontid uniquename
        evidence_code with_or_from_identifier
        annotation_type_abbreviation
        gene_product gene_synonyms_string db_object_type taxonid
        creation_date_short db)];

  my $interaction_column_names =
    [qw(gene_identifier interacting_gene_identifier
        gene_taxonid interacting_gene_taxonid evidence_code
        publication_uniquename score phenotypes comment)];

  my %type_column_names = (
    biological_process => $ontology_column_names,
    cellular_component => $ontology_column_names,
    molecular_function => $ontology_column_names,
    phenotype => $ontology_column_names,
    post_translational_modification => $ontology_column_names,
    genetic_interaction => $interaction_column_names,
    physical_interaction => $interaction_column_names,
  );

  return ($completed_count, [@annotations],
          $type_column_names{$annotation_type_name});
}

1;
