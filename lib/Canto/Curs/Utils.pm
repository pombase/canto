package Canto::Curs::Utils;

=head1 NAME

Canto::Curs::Utils - Utilities for Curs code

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::Utils

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;
use Clone qw(clone);
use JSON;

use Canto::Curs::GeneProxy;
use Canto::Curs::ConditionUtil;
use Canto::Curs::MetadataStorer;
use Canto::Track::StrainLookup;

sub _make_allelesynonym_hashes
{
  my $allele = shift;

  return map {
    {
      synonym => $_->synonym(),
      edit_status => $_->edit_status(),
    }
  } $allele->allelesynonyms()->all();
}

sub _make_genotype_details
{
  my $curs_schema = shift;
  my $genotype = shift;
  my $config = shift;
  my $ontology_lookup = shift;
  my $organism_lookup = shift;

  if (!defined $ontology_lookup) {
    die "internal error - no \$ontology_lookup passed to _make_genotype_details()";
  }
  if (!defined $organism_lookup) {
    die "internal error - no \$organism_lookup passed to _make_genotype_details()";
  }

  my %diploid_names = ();

  my $allele_genotype_rs = $curs_schema->resultset('AlleleGenotype')
    ->search({ genotype => $genotype->genotype_id() },
             {
               prefetch => [qw[diploid allele]] });

  my @alleles = ();

  while (defined (my $row = $allele_genotype_rs->next())) {
    my $allele = $row->allele();
    push @alleles, $allele;
    my $diploid = $row->diploid();
    if ($diploid) {
      push @{$diploid_names{$allele->allele_id()}}, $diploid->name();
    }
  }

  my @allele_hashes = map {
    my $allele = $_;

    my $gene_display_name;
    my $gene_id;

    if ($allele->gene()) {
      my $gene_proxy = Canto::Curs::GeneProxy->new(config => $config,
                                                   cursdb_gene => $allele->gene());
      $gene_display_name = $gene_proxy->display_name();
      $gene_id = $allele->gene()->gene_id();
    } else {
      if ($allele->type() eq 'aberration') {
        $gene_display_name = '(aberration)';
      } else {
        die 'internal error: no gene for allele: ', $allele->allele_id(), ' ',
          $allele>primary_identifier(), '\n';
      }
    }

    my @synonyms_list = _make_allelesynonym_hashes($allele);

    my $allele_obj = {
      allele_id => $allele->allele_id(),
        primary_identifier => $allele->primary_identifier(),
        type => $allele->type(),
        description => $allele->description(),
        expression => $allele->expression(),
        name => $allele->name(),
        gene_id => $gene_id,
        gene_display_name => $gene_display_name,
        long_display_name => $allele->long_identifier($config),
        display_name => $allele->display_name($config),
        synonyms => \@synonyms_list,
    };

    $allele_obj;
  } @alleles;

  map {
    if ($diploid_names{$_->{allele_id}}) {
      my $diploid_name = pop(@{$diploid_names{$_->{allele_id}}});
      if ($diploid_name) {
        $_->{diploid_name} = $diploid_name;
      }
    }
  } @allele_hashes;

  @allele_hashes = sort {
    my $a_gene = $a->{gene_display_name};
    my $b_gene = $b->{gene_display_name};

    # sort upper case last
    if ($a_gene =~ /[A-Z]/) {
      $a_gene = '~' . $a_gene;
    }
    if ($b_gene =~ /[A-Z]/) {
      $b_gene = '~' . $b_gene;
    }

    $a_gene cmp $b_gene;
  } @allele_hashes;

  my $strain_name = undef;

  my $strain = $genotype->strain();
  my $strain_lookup = Canto::Track::StrainLookup->new(config => $config);

  if ($strain) {
    $strain_name = $strain->lookup_strain_name($strain_lookup);
  }

  my $genotype_display_name = $genotype->display_name($config);

  return (
    genotype_id => $genotype->genotype_id(),
    genotype_identifier => $genotype->identifier(),
    genotype_name => $genotype->name(),
    genotype_background => $genotype->background(),
    genotype_display_name => $genotype_display_name,
    strain_name => $strain_name,
    organism => $organism_lookup->lookup_by_taxonid($genotype->organism()->taxonid()),
    feature_type => 'genotype',
    feature_display_name => $genotype_display_name,
    feature_id => $genotype->genotype_id(),
    alleles => [@allele_hashes],
  );
}

sub _make_metagenotype_details
{
  my $curs_schema = shift;
  my $metagenotype = shift;
  my $config = shift;
  my $ontology_lookup = shift;
  my $organism_lookup = shift;

  my $pathogen_genotype = $metagenotype->pathogen_genotype();
  my $host_genotype = $metagenotype->host_genotype();

  my %pathogen_genotype_details =
    _make_genotype_details($curs_schema, $pathogen_genotype, $config,
                           $ontology_lookup, $organism_lookup);
  my %host_genotype_details =
    _make_genotype_details($curs_schema, $host_genotype, $config,
                           $ontology_lookup, $organism_lookup);

  my $metagenotype_display_name =
    $pathogen_genotype_details{organism}->{full_name} . ' ' .
    $pathogen_genotype_details{genotype_display_name} . ' / ' .
    $host_genotype_details{organism}->{full_name} . ' ' .
    $host_genotype_details{genotype_display_name};

  return (
    pathogen_genotype => \%pathogen_genotype_details,
    host_genotype => \%host_genotype_details,
    metagenotype_display_name => $metagenotype_display_name,
    metagenotype_id => $metagenotype->metagenotype_id(),
    feature_type => 'metagenotype',
    feature_display_name => $metagenotype_display_name,
    feature_id => $metagenotype->metagenotype_id(),
  );
}

=head2 make_ontology_annotation

 Usage   : my $hash = Canto::Curs::Utils::make_ontology_annotation(...);
 Function: Retrieve the details of an ontology annotation from the CursDB
           as a hash
 Args    : $config - a Config object
           $schema - the CursDB schema
           $annotation - the Annotation to dump as a hash

=cut

sub make_ontology_annotation
{
  my $config = shift;
  my $schema = shift;
  my $annotation = shift;
  my $ontology_lookup = shift //
    Canto::Track::get_adaptor($config, 'ontology');
  my $organism_lookup = shift //
    Canto::Track::get_adaptor($config, 'organism');

  my $data = $annotation->data();
  my $term_ontid = $data->{term_ontid};

  die "no term_ontid for annotation " . $annotation->annotation_id()
    unless defined $term_ontid and length $term_ontid > 0;

  my $annotation_type = $annotation->type();

  my %annotation_types_config = %{$config->{annotation_types}};
  my $annotation_type_config = $annotation_types_config{$annotation_type};
  my $annotation_type_display_name = $annotation_type_config->{display_name};
  my $annotation_type_abbreviation = $annotation_type_config->{abbreviation};
  my $annotation_type_namespace = $annotation_type_config->{namespace};

  my $feature_type = $annotation_type_config->{feature_type};

  my %evidence_types = %{$config->{evidence_types}};

  my $taxonid;

  my %gene_details = ();
  my %genotype_details = ();
  my %metagenotype_details = ();

  if ($feature_type eq 'genotype') {
    my @annotation_genotypes = $annotation->genotypes();

    if (@annotation_genotypes > 1) {
      warn "internal error, more than one genotype for annotation: ",
        $annotation->annotation_id();
    }

    if (@annotation_genotypes == 0) {
      die "no genotype for annotation: ", $annotation->annotation_id();
    }

    my $genotype = $annotation_genotypes[0];

    %genotype_details = _make_genotype_details($schema, $genotype, $config,
                                               $ontology_lookup, $organism_lookup);
  }

  if ($feature_type eq 'metagenotype') {
    my @annotation_metagenotypes = $annotation->metagenotypes();

    if (@annotation_metagenotypes > 1) {
      warn "internal error, more than one metagenotype for annotation: ",
        $annotation->annotation_id();
    }

    if (@annotation_metagenotypes == 0) {
      die "no metagenotype for annotation: ", $annotation->annotation_id();
    }

    my $metagenotype = $annotation_metagenotypes[0];

    %metagenotype_details = _make_metagenotype_details($schema, $metagenotype, $config,
                                                       $ontology_lookup, $organism_lookup);
  }

  if ($feature_type eq 'gene') {
    my @annotation_genes = $annotation->genes();

    if (@annotation_genes > 1) {
      warn "internal error, more than one gene for annotation: ",
        $annotation->annotation_id();
    }

    my $gene = $annotation_genes[0];

    my $gene_proxy = Canto::Curs::GeneProxy->new(config => $config,
                                                 cursdb_gene => $gene);
    my $gene_identifier = $gene_proxy->primary_identifier();
    my $gene_primary_name = $gene_proxy->primary_name() || '';
    my $gene_name_or_identifier = $gene_proxy->primary_name() || $gene_proxy->primary_identifier();
    my $gene_product = $gene_proxy->product() || '',
      my $gene_synonyms_string = join '|', $gene_proxy->synonyms();

    $taxonid = $gene_proxy->taxonid();

    %gene_details = (
      gene_id => $gene->gene_id(),
      gene_identifier => $gene_identifier,
      gene_name => $gene_primary_name,
      gene_name_or_identifier => $gene_name_or_identifier,
      gene_product => $gene_product,
      gene_synonyms_string => $gene_synonyms_string,
      organism => $organism_lookup->lookup_by_taxonid($gene->organism()->taxonid()),
      feature_type => 'gene',
      feature_display_name => $gene_name_or_identifier,
      feature_id => $gene->gene_id(),
    );
  }

  my $pub_uniquename = $annotation->pub()->uniquename();

  my $term_lookup_result = $ontology_lookup->lookup_by_id(id => $term_ontid);

  if (! defined $term_lookup_result) {
    warn qq(internal error: cannot find details for "$term_ontid" in "$annotation_type");
    $term_lookup_result = {
      name => "[UNKNOWN TERM]",
      is_obsolete => 1,
    };
  }

  my $term_name = $term_lookup_result->{name};

  my $evidence_code = $data->{evidence_code};
  my $with_gene_identifier = $data->{with_gene};
  my $is_obsolete_term = $term_lookup_result->{is_obsolete};
  my $curator = undef;
  if (defined $data->{curator}) {
    $curator = $data->{curator}->{name} . ' <' . $data->{curator}->{email} . '>';
  }

  my $needs_with;
  if (defined $evidence_code) {
    $needs_with = $evidence_types{$evidence_code}->{with_gene};
  } else {
    $needs_with = 0;
  }

  my $with_gene;
  my $with_gene_id;
  my $with_gene_display_name;

  if ($with_gene_identifier) {
    $with_gene = $schema->find_with_type('Gene',
                                         { primary_identifier =>
                                             $with_gene_identifier });
    my $gene_proxy = Canto::Curs::GeneProxy->new(config => $config,
                                                  cursdb_gene => $with_gene);
    $with_gene_display_name = $gene_proxy->display_name();
    $with_gene_id = $with_gene->gene_id();
  }

  (my $short_date = $annotation->creation_date()) =~ s/-//g;

  my $completed = defined $evidence_code &&
    (!$needs_with || defined $with_gene_identifier);

  my $ret = {
    %gene_details,
    %genotype_details,
    %metagenotype_details,
    feature_type => $feature_type,
    qualifiers => $data->{qualifiers} // [],
    annotation_type => $annotation_type,
    annotation_type_display_name => $annotation_type_display_name,
    annotation_type_abbreviation => $annotation_type_abbreviation // '',
    annotation_id => $annotation->annotation_id(),
    publication_uniquename => $pub_uniquename,
    term_ontid => $term_ontid,
    term_name => $term_name,
    evidence_code => $evidence_code,
    creation_date => $annotation->creation_date(),
    creation_date_short => $short_date,
    submitter_comment => $data->{submitter_comment},
    term_suggestion_name => $data->{term_suggestion}->{name},
    term_suggestion_definition => $data->{term_suggestion}->{definition},
    needs_with => $needs_with,
    with_or_from_identifier => $with_gene_identifier,
    with_or_from_display_name => $with_gene_display_name,
    with_gene_id => $with_gene_id,
    taxonid => $taxonid,
    completed => $completed,
    extension => $data->{extension} || [],
    is_obsolete_term => $is_obsolete_term,
    curator => $curator,
    status => $annotation->status(),
    is_not => JSON::false,
    checked => $data->{checked} || 'no',
  };

  if ($feature_type ne 'gene') {
    $ret->{conditions} =
      [Canto::Curs::ConditionUtil::get_conditions_with_names($ontology_lookup, $data->{conditions})];
  }

 return $ret;
}

=head2 make_interaction_annotation

 Usage   : my $hash = Canto::Curs::Utils::make_interaction_annotation(...);
 Function: Retrieve the details of an interaction annotation from the CursDB as
           a hash
 Args    : $config - a Config object
           $schema - the CursDB schema
           $annotation - the Annotation to dump as a hash

=cut

sub make_interaction_annotation
{
  my $config = shift;
  my $schema = shift;
  my $annotation = shift;

  my $ontology_lookup = shift //
    Canto::Track::get_adaptor($config, 'ontology');
  my $organism_lookup = shift //
    Canto::Track::get_adaptor($config, 'organism');


  my @metagenotype_annotations = $annotation->metagenotype_annotations()
    ->search({ },
             { prefetch => {
               metagenotype => {
                 first_genotype => 'organism',
                 second_genotype => 'organism'
               }
             } });

  if (@metagenotype_annotations > 1) {
    die "internal error, more than one metagenotype for annotation: ",
      $annotation->annotation_id();
  }

  if (@metagenotype_annotations == 0) {
    use Data::Dumper;
    warn Dumper([$annotation->annotation_id(), $annotation->data()]);
  }

  my $metagenotype = $metagenotype_annotations[0]->metagenotype();

  my $genotype_a = $metagenotype->first_genotype();
  my $genotype_b = $metagenotype->second_genotype();

  my $organism_a = $genotype_a->organism();
  my $organism_b = $genotype_b->organism();

  my @genotype_a_gene_ids =
    map {
      my $gene = $_;
      $gene->gene_id();
    }
    grep {
      my $gene = $_;
      defined $gene;
    } map {
      my $allele = $_;
      $allele->gene();
    } $genotype_a->alleles();

  my @genotype_b_gene_ids =
    map {
      my $gene = $_;
      $gene->gene_id();
    }
    grep {
      my $gene = $_;
      defined $gene;
    } map {
      my $allele = $_;
      $allele->gene();
    } $genotype_b->alleles();


  my $is_inferred_annotation = 0;

  my $data = $annotation->data();
  my $evidence_code = $data->{evidence_code};
  my $annotation_type = $annotation->type();

  my $term_name = '';

  my $term_ontid = $data->{term_ontid};
  my $is_obsolete_term = undef;

  if ($term_ontid) {
    my $term_lookup_result = $ontology_lookup->lookup_by_id(id => $term_ontid);

    if (! defined $term_lookup_result) {
      warn qq(internal error: cannot find details for "$term_ontid" in "$annotation_type");
      $term_lookup_result = {
        name => "[UNKNOWN TERM]",
        is_obsolete => 1,
      };
    }

    $term_name = $term_lookup_result->{name};
    $is_obsolete_term = $term_lookup_result->{is_obsolete};
  }

  my %annotation_types_config = %{$config->{annotation_types}};
  my $annotation_type_config = $annotation_types_config{$annotation_type};
  my $annotation_type_display_name = $annotation_type_config->{display_name};

  my $pub_uniquename = $annotation->pub()->uniquename();
  my $curator = undef;
  if (defined $data->{curator}) {
    $curator = $data->{curator}->{name} . ' <' . $data->{curator}->{email} . '>';
  }

  my $organism_hash = clone $organism_lookup->lookup_by_taxonid($organism_a->taxonid());

  delete $organism_hash->{genes};

  my $entry =
    {
      organism => $organism_hash,
      annotation_type => $annotation_type,
      annotation_type_display_name => $annotation_type_display_name,
      genotype_a_display_name => $genotype_a->display_name($config),
      genotype_a_id => $genotype_a->genotype_id(),
      genotype_a_taxonid => $organism_a->taxonid(),
      genotype_a_gene_ids => \@genotype_a_gene_ids,
      publication_uniquename => $pub_uniquename,
      evidence_code => $evidence_code,
      genotype_b_display_name => $genotype_b->display_name($config),
      genotype_b_id => $genotype_b->genotype_id(),
      genotype_b_taxonid => $organism_b->taxonid(),
      genotype_b_gene_ids => \@genotype_b_gene_ids,
      score => '',  # for biogrid format output
      submitter_comment => $data->{submitter_comment} // '',
      term_ontid => $term_ontid,
      term_name => $term_name,
      is_obsolete_term => $is_obsolete_term,
      extension => $data->{extension} || [],
      completed => 1,
      annotation_id => $annotation->annotation_id(),
      annotation_type => $annotation_type,
      status => $annotation->status(),
      curator => $curator,
      is_inferred_annotation => $is_inferred_annotation,
      checked => $data->{checked} || 'no',
    };

  $entry->{conditions} =
    [Canto::Curs::ConditionUtil::get_conditions_with_names($ontology_lookup, $data->{conditions})];

  return $entry;
};

=head2 get_annotation_table

 Usage   : my @annotations =
             Canto::Curs::Utils::get_annotation_table($config, $schema,
                                                      $annotation_type_name,
                                                      $constrain_annotations,
                                                      $constrain_feature);
 Function: Return a table of the current annotations
 Args    : $config - the Canto::Config object
           $schema - a Canto::CursDB object
           $annotation_type_name - the type of annotation to show (eg.
                                   biological_process, phenotype)
           $constrain_annotations - restrict the table to these annotations
           $constrain_feature     - the gene or genotype to show annotations for
 Returns : ($completed_count, $table)
           where:
             $completed_count - a count of the annotations that are incomplete
                because they need an evidence code or a with field, etc.
             $table - an array of hashes containing the annotation

 The returned table has this format if the annotation_type_name is an ontology
 type:
    [ { gene_identifier => 'SPCC1739.11c',
        gene_name => 'cdc11',
        annotation_type => 'molecular_function',
        annotation_id => 1234,
        term_ontid => 'GO:0055085',
        term_name => 'transmembrane transport',
        evidence_code => 'IDA',
        ... },
      { gene_identifier => '...', ... }, ]
    where annotation_id is the id of the Annotation object for this annotation

 If the annotation_type_name is an interaction type the format is:
    [ { gene_identifier => 'SPCC1739.11c',
        gene_display_name => 'cdc11',
        gene_taxonid => 4896,
        publication_uniquename => 'PMID:20870879',
        evidence_code => 'Phenotypic Enhancement',
        interacting_gene_identifier => 'SPBC12C2.02c',
        interacting_gene_display_name => 'ste20',
        interacting_gene_taxonid => 4896
        annotation_id => 1234,
        ... },
      { gene_identifier => '...', ... }, ]
    where annotation_id is the id of the Annotation object for this annotation

=cut
sub get_annotation_table
{
  my $config = shift;
  my $schema = shift;
  my $annotation_type_name = shift;
  my $constrain_annotations = shift;
  my $constrain_feature = shift;

  my @annotations = ();

  my %annotation_types_config = %{$config->{annotation_types}};
  my $annotation_type_config = $annotation_types_config{$annotation_type_name};
  my $annotation_type_category = $annotation_type_config->{category};

  my $ontology_lookup =
    Canto::Track::get_adaptor($config, 'ontology');
  my $organism_lookup =
    Canto::Track::get_adaptor($config, 'organism');

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

  my %options = ( order_by => 'annotation_id', prefetch => 'pub' );

  my $annotation_rs =
    $schema->resultset('Annotation')->search({ %constraints }, { %options });;

  while (defined (my $annotation = $annotation_rs->next())) {
    my @entries;
    if ($annotation_type_category eq 'ontology') {
      @entries = make_ontology_annotation($config, $schema, $annotation,
                                          $ontology_lookup, $organism_lookup);
    } else {
      if ($annotation_type_category eq 'interaction') {

        @entries = make_interaction_annotation($config, $schema, $annotation,
                                               $ontology_lookup, $organism_lookup);
      } else {
        die "unknown annotation type category: $annotation_type_category\n";
      }
    }
    push @annotations, @entries;
    map { $completed_count++ if $_->{completed} } @entries;
  }

  return ($completed_count, [@annotations])
}

sub _process_existing_db_ontology
{
  my $config = shift;
  my $curs_schema = shift;
  my $ontology_lookup = shift;
  my $row = shift;

  my $feature = $row->{gene} // $row->{genotype};
  my $gene = $row->{gene};
  my $genotype = $row->{genotype};
  my $feature_type;

  if ($gene) {
    $feature_type = 'gene';
  } else {
    $feature_type = 'genotype';
  }


  my $ontology_term = $row->{ontology_term};
  my $publication = $row->{publication};
  my $evidence_code = $row->{evidence_code};
  my $gene_product_form_id = $row->{gene_product_form_id};
  my $ontology_name = $ontology_term->{ontology_name};

  my $term_name = $row->{ontology_term}->{term_name};;

  my $term_ontid = $ontology_term->{ontid};

  my $is_not;

  if ($row->{is_not}) {
    $is_not = JSON::true;
  } else {
    $is_not = JSON::false;
  }

  my $annotation_type_config =
    $config->{annotation_types_by_namespace}->{$ontology_name}->[0] //
    $config->{annotation_types}->{$ontology_name};

  my $annotation_type = $annotation_type_config->{name};

  my $with_or_from_identifier = $row->{with} // $row->{from};

  my $gene_id = undef;
  my $with_gene_id = undef;

  my $genotype_id = undef;

  if (defined $curs_schema) {
    if ($gene) {
      my $db_gene = $curs_schema->resultset('Gene')->find({ primary_identifier => $gene->{identifier} });

      if (defined $db_gene) {
        $gene_id = $db_gene->gene_id();
      }

      # disabled for now - no linking for with identifiers in existing annotations
      if (0 && defined $with_or_from_identifier) {
        my $db_with_gene = $curs_schema->resultset('Gene')->find({
          primary_identifier => $with_or_from_identifier,
        });

        if (!defined $db_with_gene && $with_or_from_identifier =~ /.*:(\S+)/) {
          $db_with_gene = $curs_schema->resultset('Gene')->find({
            primary_identifier => $1,
          });
        }

        if (defined $db_with_gene) {
          $with_gene_id = $db_with_gene->gene_id();
        }
      }
    } else {
      my $db_genotype = $curs_schema->resultset('Genotype')->find({ identifier => $genotype->{identifier} });

      if (defined $db_genotype) {
        $genotype_id = $db_genotype->genotype_id();
      }
    }
  }

  my %ret = (
    annotation_id => $row->{annotation_id},
    feature_type => $feature_type,
    feature_display_name =>
      $feature->{name} || $feature->{identifier},
    feature_id => $gene_id // $genotype_id,
    conditions => [Canto::Curs::ConditionUtil::get_conditions_with_names($ontology_lookup, $row->{conditions})],
    qualifiers => $row->{qualifiers} // [],
    annotation_type => $annotation_type,
    term_ontid => $term_ontid,
    term_name => $term_name,
    evidence_code => $evidence_code,
    status => 'existing',
    is_not => $is_not,
    extension => $row->{extension},
  );

  if ($gene) {
    $ret{gene_identifier} = $gene->{identifier};
    $ret{gene_name} = $gene->{name} || '';
    $ret{gene_name_or_identifier} = $gene->{name} || $gene->{identifier};
    $ret{gene_product} = $gene->{product} || '';
    $ret{gene_id} = $gene_id;
    $ret{taxonid} = $gene->{organism_taxonid};
    $ret{with_or_from_identifier} = $with_or_from_identifier;
    $ret{with_or_from_display_name} = $with_or_from_identifier;
    $ret{with_gene_id} = $with_gene_id;
    $ret{gene_product_form_id} = $gene_product_form_id;
  } else {
    $ret{genotype_identifier} = $genotype->{identifier};
    $ret{genotype_name} = $genotype->{name} || '';
    $ret{genotype_name_or_identifier} = $genotype->{name} || $genotype->{identifier};
    $ret{genotype_id} = $genotype_id;
    $ret{alleles} = [map {
      my %ret = %$_;
      $ret{long_display_name} =
        ($ret{name} || $ret{gene_display_name} . ':unnamed') .
        '(' . ($ret{description} || 'unknown') . ')';

      if ($_->{expression}) {
        $ret{long_display_name} .= '[' . $_->{expression} . ']';
      }

      \%ret;
    } @{$genotype->{alleles}}]
  }

  return \%ret;
}

=head2 get_existing_ontology_annotations

 Usage   :
   my ($all_annotations_count, $annotations) =
     Canto::Curs::Utils::get_existing_ontology_annotations($config, $curs_schema, $options);
 Function: Return a count of the all the matching annotations and table of the
           existing ontology annotations from the database with at most
           max_results rows
 Args    : $options->{pub_uniquename} - the identifier of the publication,
               usually the PubMed ID to get annotations for
           $options->{gene_identifier} - the gene identifier to use to constrain
               the search; only annotations for the gene are returned (optional)
           $options->{ontology_name} - the ontology name to use to restrict the
               search; only annotations using terms from this ontology are
               returned (optional)
           $options->{max_results} - maximum number of annotations to return
 Returns : An array of hashes containing the annotation in the same form as
           get_annotation_table() above, except that annotation_id will be a
           database identifier for the annotation.

=cut
sub get_existing_ontology_annotations
{
  my $config = shift;
  my $curs_schema = shift;
  my $options = shift;

  my $pub_uniquename = $options->{pub_uniquename};
  my $gene_identifier = $options->{gene_identifier};
  my $ontology_name = $options->{annotation_type_name};
  my $max_results = $options->{max_results} // 0;

  my $args = {
    pub_uniquename => $pub_uniquename,
    gene_identifier => $gene_identifier,
    ontology_name => $ontology_name,
    max_results => $max_results,
  };

  my $ontology_lookup =
    Canto::Track::get_adaptor($config, 'ontology');
  my $annotation_lookup =
    Canto::Track::get_adaptor($config, 'ontology_annotation');

  my @res = ();

  my $all_annotations_count = 0;

  if (defined $annotation_lookup) {
    my $lookup_ret_interactions;
    ($all_annotations_count, $lookup_ret_interactions) =
      $annotation_lookup->lookup($args);

    @res = map {
      my $res = _process_existing_db_ontology($config, $curs_schema, $ontology_lookup, $_);
      if (defined $res) {
        ($res);
      } else {
        ();
      }
    } @{$lookup_ret_interactions};
  }

  return ($all_annotations_count, \@res);
}

sub _process_interaction
{
  my $curs_schema = shift;
  my $ontology_lookup = shift;
  my $row = shift;
  my $annotation_type = shift;

  my $gene = $row->{gene};
  my $interacting_gene = $row->{interacting_gene};
  my $publication = $row->{publication};

  my $gene_id = undef;
  my $interacting_gene_id = undef;

  if (defined $curs_schema) {
    my $db_gene = $curs_schema->resultset('Gene')->find({ primary_identifier => $gene->{identifier} });

    if (defined $db_gene) {
      $gene_id = $db_gene->gene_id();
    }

    my $db_interacting_gene = $curs_schema->resultset('Gene')->find({ primary_identifier => $interacting_gene->{identifier} });

    if (defined $db_interacting_gene) {
      $interacting_gene_id = $db_interacting_gene->gene_id();
    }
  }

  return {
    annotation_type => $row->{annotation_type},
    gene_identifier => $gene->{identifier},
    gene_display_name => $gene->{name} // $gene->{identifier},
    gene_taxonid => $gene->{taxonid},
    gene_id => $gene_id,
    publication_uniquename => $publication->{uniquename},
    evidence_code => $row->{evidence_code},
    interacting_gene_identifier => $interacting_gene->{identifier},
    interacting_gene_display_name =>
      $interacting_gene->{name} // $interacting_gene->{identifier},
    interacting_gene_taxonid => $interacting_gene->{taxonid},
    interacting_gene_id => $interacting_gene_id,
    status => 'existing',
  };
}

=head2 get_existing_interaction_annotations

 Usage   :
   my ($all_existing_annotations_count, $annotations) =
      Canto::Curs::Utils::get_existing_interaction_annotations($config, $curs_schema, $options);
 Function: Return a count of the all the matching interactions and table of the
           existing interactions from the database with at most max_results rows
 Args    : $config - the Canto::Config object
           $options->{pub_uniquename} - the publication ID (eg. PubMed ID)
               to retrieve annotations from
           $options->{gene_identifier} - the gene identifier to use to constrain
               the search; only annotations for the gene are returned (optional)
           $options->{max_results} - maximum number of interactions to return
 Returns : An array of hashes containing the annotation in the same form as
           get_annotation_table() above, except that annotation_id will be a
           database identifier for the annotation.

=cut
sub get_existing_interaction_annotations
{
  my $config = shift;
  my $curs_schema = shift;
  my $options = shift;

  my $pub_uniquename = $options->{pub_uniquename};
  my $gene_identifier = $options->{gene_identifier};
  my $interaction_type_name = $options->{annotation_type_name};
  my $max_results = $options->{max_results};

  my $args = {
    pub_uniquename => $pub_uniquename,
    gene_identifier => $gene_identifier,
    interaction_type_name => $interaction_type_name,
    max_results => $max_results,
  };

  my $annotation_lookup =
    Canto::Track::get_adaptor($config, 'interaction_annotation');

  my $all_interactions_count = 0;
  my @res = ();

  if (defined $annotation_lookup) {
    my $lookup_ret_interactions;
    ($all_interactions_count, $lookup_ret_interactions) =
      $annotation_lookup->lookup($args);
    if (!defined $all_interactions_count) {
      use Data::Dumper;
      die "annotation lookup returned undef count for args: ",
        Dumper([$args]);
    }
    @res = map {
      my $res = _process_interaction($curs_schema, $annotation_lookup, $_);
      if (defined $res) {
        ($res);
      } else {
        ();
      }
    } @{$lookup_ret_interactions};
  }

  return ($all_interactions_count, \@res);
}

=head2 get_existing_annotations

 Usage   :
   my ($all_annotations_count, $annotations) =
     Canto::Curs::Utils::get_existing_annotations($config, $curs_schema, $options);
 Function: Return a table of the existing interaction annotations from the
           database
 Args    : $config - the Canto::Config object
           $options->{pub_uniquename} - the publication ID (eg. PubMed ID)
               to retrieve annotations from
           $options->{gene_identifier} - the gene identifier to use to constrain
               the search; only annotations for the gene are returned (optional)
           $options->{annotation_type_name} - the annotation type eg.
               'biological_process', 'physical_interaction'
 Returns : An array of hashes containing the annotation in the same form as
           get_annotation_table() above, except that annotation_id will be a
           database identifier for the annotation.

=cut

sub get_existing_annotations
{
  my $config = shift;
  my $curs_schema = shift;
  my $options = shift;

  my $annotation_type_category =
    $config->{annotation_types}->{$options->{annotation_type_name}}->{category};

  if ($annotation_type_category eq 'ontology') {
    return get_existing_ontology_annotations($config, $curs_schema, $options);
  } else {
    return get_existing_interaction_annotations($config, $curs_schema, $options);
  }
}

=head2 get_existing_annotation_count

 Usage   : my $count = Canto::Curs::Utils::get_existing_annotation_count($config, $options);
 Function: Return the total number of existing annotations for a publication
 Args    : $config - the Canto::Config object
           $options -
             $options->{pub_uniquename} - the publication ID (eg. PubMed ID)
                 to count annotations of
 Return  : the count

=cut

sub get_existing_annotation_count
{
  my $config = shift;
  my $curs_schema = shift;
  my $arg_options = shift;

  my $count = 0;

  for my $annotation_type (@{$config->{annotation_type_list}}) {
    my $options = clone $arg_options;
    $options->{annotation_type_name} = $annotation_type->{name};
    my ($all_annotations_count, $annotations) =
      Canto::Curs::Utils::get_existing_annotations($config, $curs_schema, $options);
    $count += $all_annotations_count;
  }

  return $count;
}

=head2 store_all_statuses

 Usage   : Canto::Curs::Utils::store_all_statuses($config, $schema);
 Function: Store the current status of all Curs DBs in the Track DB
 Args    : $config - the Canto::Config object
           $schema - a Canto::TrackDB object
 Returns :

=cut

sub store_all_statuses
{
  my $config = shift;
  my $track_schema = shift;

  my $metadata_storer =
   Canto::Curs::MetadataStorer->new(config => $config);

  my $iter = Canto::Track::curs_iterator($config, $track_schema);
  while (my ($curs, $cursdb) = $iter->()) {
    $metadata_storer->store_counts($cursdb);
  }
}

=head2 canto_allele_type

 Usage   : my $type_name =
             Canto::Curs::Utils::canto_allele_type($chado_type, $allele_description);
 Function:
    Return the Canto allele type given a Chado (or "export") allele
    type and the allele description - Canto has different types for a
    single amino acid residue change and a multi amino acid change but
    Chado just has "amino_acid_mutation".  We use the
    export_type_reverse_map config field from the allele_type YAML config
    to map the Chado type to the Canto type.
 Args    : $config - the Config object
           $chado_type - the allele_type of the allele from the featureprop
                         table
           $allele_description - the allele description from the featureprop
                                 table
 Return  : a allele type for the Canto interface

=cut

sub canto_allele_type
{
  my $config = shift;
  my $chado_type = shift;
  my $allele_description = shift;

  my @canto_allele_types = @{$config->{export_type_to_allele_type}->{$chado_type}};

  if (@canto_allele_types == 0) {
    warn qq(no allele type found for Chado allele_type "$chado_type"\n);
    return $chado_type;
  } else {
    if (@canto_allele_types == 1) {
      return $canto_allele_types[0]->{name};
    } else {
      for my $allele_type (@canto_allele_types) {
        my $export_type_reverse_map_re =
          $allele_type->{export_type_reverse_map_re};
        if (!defined $export_type_reverse_map_re) {
          die "no export_type_reverse_map_re config found for ", $allele_type->{name};
        }
        if ($allele_description =~ /$export_type_reverse_map_re/) {
          return $allele_type->{name};
        }
      }

      die "no Canto allele type found for: $chado_type";
    }
  }
}



=head2 make_allele_display_name

 Usage   : $dis_name = make_allele_display_name($name, $description, $type);
 Function: make an allele display name from a name and description
 Args    : $name - the allele name (can be undef)
           $description - the allele description (can be undef)
           $type - the allele type (deletion, unknown, ...)
 Returns : a display name of the form "name(description)" or "name" (if the
           description is "deletion" or "wild type")

=cut

sub make_allele_display_name
{
  my $config = shift;
  my $name = shift || 'unnamed';
  my $description = shift;
  my $type = shift;

  my $allele_type_config = $config->{allele_types}->{$type};

  if ($type eq 'deletion' && $name =~ /delta$/ ||
        $type =~ /^wild[\s_]?type$/ && $name =~ /(\+|\[\+\])$/ ||
      $allele_type_config && $allele_type_config->{hide_type_name}) {
    if ($description &&
        $description =~ s/[\s_]+//gr ne $type =~ s/[\s_]+//gr) {
      return "$name($description)";
    } else {
      return $name;
    }
  }

  $description ||= $type || 'unknown';

  if ($type =~ /^mutation|substitution/) {
    if ($type =~ /amino acid/) {
      $description =~ s/^/aa/g;
    } else {
      if ($type =~ /nucleotide/) {
        $description =~ s/^/nt/g;
      }
    }
  }

  if ($type eq 'other' && $name eq $description) {
    return $name;
  }

  return "$name($description)";
}

=head2

 Usage   : my $annotation_deleted =
             Canto::Curs::Utils::delete_interactor($annotation, $interactor_identifier);
 Function: Remove an interactor from an interaction annotation and
           remove the annotation if that interactor was the only one.
 Args    : $annotation - the Annotation object
           $interactor_identifier - the identifier of the interactor
                                    to remove
 Returns : 1 if the annotation was deleted, 0 otherwise

=cut

sub delete_interactor
{
  my $annotation = shift;
  my $interactor_identifier = shift;

  my $data = $annotation->data();
  if (@{$data->{interacting_genes}} <= 1) {
    $annotation->delete();
  } else {
    $data->{interacting_genes} =
      [grep {
        $_->{primary_identifier} ne $interactor_identifier;
      } @{$data->{interacting_genes}}];
    $annotation->data($data);
    $annotation->update();
  }

}

my $iso_date_template = "%4d-%02d-%02d";

=head2 get_iso_date

 Usage   : $date_string = Canto::Curs::get_iso_date();
 Function: return the current date and time in ISO format

=cut

sub get_iso_date
{
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
  return sprintf "$iso_date_template", 1900+$year, $mon+1, $mday
}

1;
