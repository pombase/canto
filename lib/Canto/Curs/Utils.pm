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

use Canto::Curs::GeneProxy;

# retrieve annotation data from the CursDB
sub _make_ontology_annotation
{
  my $config = shift;
  my $schema = shift;
  my $annotation = shift;
  my $ontology_lookup = shift;

  my $data = $annotation->data();
  my $term_ontid = $data->{term_ontid};

  die "no term_ontid for annotation"
    unless defined $term_ontid and length $term_ontid > 0;

  my $annotation_type = $annotation->type();

  my %annotation_types_config = %{$config->{annotation_types}};
  my $annotation_type_config = $annotation_types_config{$annotation_type};
  my $annotation_type_display_name = $annotation_type_config->{display_name};
  my $annotation_type_abbreviation = $annotation_type_config->{abbreviation};
  my $annotation_type_namespace = $annotation_type_config->{namespace};

  my %evidence_types = %{$config->{evidence_types}};

  my $allele_display_name = undef;
  my $expression_level = '';
  my $conditions_string = '';

  my $gene;

  my @alleles = $annotation->search_related('allele_annotations')
    ->search_related('allele')->search({}, { prefetch => 'gene' });;

  if ($annotation_type_config->{needs_allele} && @alleles) {
    if (@alleles > 1) {
      die "more than one allele for annotation ", $annotation->annotation_id();
    }

    my $allele = $alleles[0];

    $allele_display_name = $allele->display_name();

    $gene = $allele->gene();

    $expression_level = $data->{expression} // 'null';

    if ($data->{conditions}) {
      $conditions_string = _get_conditions_string($ontology_lookup,
                                                  $data->{conditions});
    } else {
      $conditions_string = '';
    }
  } else {
    my @annotation_genes = $annotation->genes();

    if (@annotation_genes > 1) {
      die "internal error, more than one gene for annotation: ",
        $annotation->annotation_id();
    }

    $gene = $annotation_genes[0];
  }

  my $gene_proxy = Canto::Curs::GeneProxy->new(config => $config,
                                                cursdb_gene => $gene);
  my $gene_identifier = $gene_proxy->primary_identifier();
  my $gene_primary_name = $gene_proxy->primary_name() || '';
  my $gene_name_or_identifier = $gene_proxy->primary_name() || $gene_proxy->primary_identifier();
  my $gene_product = $gene_proxy->product() || '',
  my $gene_synonyms_string = join '|', $gene_proxy->synonyms();

  my $taxonid = $gene_proxy->organism()->taxonid();

  my $pub_uniquename = $annotation->pub()->uniquename();

  my $term_lookup_result = $ontology_lookup->lookup_by_id(id => $term_ontid);

  if (! defined $term_lookup_result) {
    die qq(internal error: can't find details for "$term_ontid" in "$annotation_type");
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
  my $with_gene_display_name;

  if ($with_gene_identifier) {
    $with_gene = $schema->find_with_type('Gene',
                                         { primary_identifier =>
                                             $with_gene_identifier });
    my $gene_proxy = Canto::Curs::GeneProxy->new(config => $config,
                                                  cursdb_gene => $with_gene);
    $with_gene_display_name = $gene_proxy->display_name()
  }

  (my $short_date = $annotation->creation_date()) =~ s/-//g;

  my $completed = defined $evidence_code &&
    (!$needs_with || defined $with_gene_identifier);

  return {
    gene_id => $gene->gene_id(),
    gene_identifier => $gene_identifier,
    gene_name => $gene_primary_name,
    gene_name_or_identifier => $gene_name_or_identifier,
    gene_product => $gene_product,
    gene_synonyms_string => $gene_synonyms_string,
    allele_display_name => $allele_display_name,
    qualifiers => '',
    annotation_type => $annotation_type,
    annotation_type_display_name => $annotation_type_display_name,
    annotation_type_abbreviation => $annotation_type_abbreviation // '',
    annotation_id => $annotation->annotation_id(),
    publication_uniquename => $pub_uniquename,
    term_ontid => $term_ontid,
    term_name => $term_name,
    evidence_code => $evidence_code,
    expression_level => $expression_level,
    conditions => $conditions_string,
    creation_date => $annotation->creation_date(),
    creation_date_short => $short_date,
    comment => $data->{submitter_comment},
    term_suggestion => $data->{term_suggestion},
    needs_with => $needs_with,
    with_or_from_identifier => $with_gene_identifier,
    with_or_from_display_name => $with_gene_display_name,
    taxonid => $taxonid,
    completed => $completed,
    annotation_extension => $data->{annotation_extension} // '',
    is_obsolete_term => $is_obsolete_term,
    curator => $curator,
    status => $annotation->status(),
    is_not => 0,
  };
}

sub _make_interaction_annotation
{
  my $config = shift;
  my $schema = shift;
  my $annotation = shift;
  my $constrain_gene = shift;

  my @annotation_genes = $annotation->genes();

  if (@annotation_genes > 1) {
    die "internal error, more than one gene for annotation: ",
      $annotation->annotation_id();
  }

  my $gene = $annotation_genes[0];

  my $is_inferred_annotation = 0;

  my $gene_proxy =
    Canto::Curs::GeneProxy->new(config => $config,
                                 cursdb_gene => $gene);

  my $data = $annotation->data();
  my $evidence_code = $data->{evidence_code};
  my $annotation_type = $annotation->type();

  my %annotation_types_config = %{$config->{annotation_types}};
  my $annotation_type_config = $annotation_types_config{$annotation_type};
  my $annotation_type_display_name = $annotation_type_config->{display_name};

  my $pub_uniquename = $annotation->pub()->uniquename();
  my $curator = undef;
  if (defined $data->{curator}) {
    $curator = $data->{curator}->{name} . ' <' . $data->{curator}->{email} . '>';
  }

  my @interacting_genes = @{$data->{interacting_genes}};

  my @results = ();

  for my $interacting_gene_info (@interacting_genes) {
    my $interacting_gene_primary_identifier =
      $interacting_gene_info->{primary_identifier};
    my $interacting_gene =
      $schema->find_with_type('Gene',
                              { primary_identifier =>
                                $interacting_gene_primary_identifier});
    my $interacting_gene_proxy =
      Canto::Curs::GeneProxy->new(config => $config,
                                   cursdb_gene => $interacting_gene);

    my $interacting_gene_display_name =
      $interacting_gene_proxy->display_name();

    if (defined $constrain_gene) {
      if ($constrain_gene->gene_id() != $gene->gene_id()) {
        if ($interacting_gene->gene_id() == $constrain_gene->gene_id()) {
          $is_inferred_annotation = 1;
        } else {
          # ignore bait or prey from this annotation if it isn't the
          # current gene (on a gene page)
          next;
        }
      }
    }

    my $entry =
          {
            gene_identifier => $gene_proxy->primary_identifier(),
            gene_display_name => $gene_proxy->display_name(),
            gene_taxonid => $gene_proxy->organism()->taxonid(),
            gene_id => $gene_proxy->gene_id(),
            publication_uniquename => $pub_uniquename,
            evidence_code => $evidence_code,
            interacting_gene_identifier =>
              $interacting_gene_primary_identifier,
            interacting_gene_display_name =>
              $interacting_gene_display_name,
            interacting_gene_taxonid =>
              $interacting_gene_info->{organism_taxon}
                // $gene_proxy->organism()->taxonid(),
            interacting_gene_id => $interacting_gene_proxy->gene_id(),
            score => '',  # for biogrid format output
            phenotypes => '',
            comment => '',
            completed => 1,
            annotation_id => $annotation->annotation_id(),
            annotation_type => $annotation_type,
            status => $annotation->status(),
            curator => $curator,
            is_inferred_annotation => $is_inferred_annotation,
          };
    push @results, $entry;
  };

  return @results;
};

=head2 get_annotation_table

 Usage   : my @annotations =
             Canto::Curs::Utils::get_annotation_table($config, $schema,
                                                       $annotation_type_name);
 Function: Return a table of the current annotations
 Args    : $config - the Canto::Config object
           $schema - a Canto::CursDB object
           $annotation_type_name - the type of annotation to show (eg.
                                   biological_process, phenotype)
           $constrain_annotations - restrict the table to these annotations
           $constrain_gene        - the gene to show annotations for
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
  my $constrain_gene = shift;

  my @annotations = ();

  my %annotation_types_config = %{$config->{annotation_types}};
  my $annotation_type_config = $annotation_types_config{$annotation_type_name};
  my $annotation_type_category = $annotation_type_config->{category};

  my $ontology_lookup =
    Canto::Track::get_adaptor($config, 'ontology');

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
      @entries = _make_ontology_annotation($config, $schema, $annotation,
                                            $ontology_lookup);
    } else {
      if ($annotation_type_category eq 'interaction') {
        @entries = _make_interaction_annotation($config, $schema, $annotation, $constrain_gene);
      } else {
        die "unknown annotation type category: $annotation_type_category\n";
      }
    }
    push @annotations, @entries;
    map { $completed_count++ if $_->{completed} } @entries;
  }

  return ($completed_count, [@annotations])
}

sub _get_conditions_string
{
  my $ontology_lookup = shift;
  my $conditions = shift;

  return '' unless defined $conditions;

  my @condition_names = map {
    my $ret_val;
    my $term_id = $_;
    if ($term_id =~ /^[A-Z]+:/) {
      my $result = $ontology_lookup->lookup_by_id(id => $term_id);
      if (defined $result) {
        $ret_val = $result->{name} . " ($term_id)";
      }
    }
    if (defined $ret_val) {
      $ret_val;
    } else {
      # some conditions are just free text if the user couldn't find the
      # appropriate PECO term
      "$term_id (NEW)";
    }
  } @$conditions;

  return join ', ', @condition_names;
}

sub _process_existing_db_ontology
{
  my $ontology_lookup = shift;
  my $row = shift;

  my $gene = $row->{gene};
  my $ontology_term = $row->{ontology_term};
  my $publication = $row->{publication};
  my $evidence_code = $row->{evidence_code};
  my $ontology_name = $ontology_term->{ontology_name};

  my $term_name =
    $row->{ontology_term}->{extension_term_name} // $row->{ontology_term}->{term_name};;

  my $term_ontid = $ontology_term->{ontid};

  my $is_not = $row->{is_not} // 0;
  if ($is_not eq 'false') {
    $is_not = 0;
  }

  my $allele_display_name =
    Canto::Curs::Utils::make_allele_display_name($row->{allele}->{name},
                                                  $row->{allele}->{description});


  my $conditions_string = _get_conditions_string($ontology_lookup, $row->{conditions});
  my $qualifier_string = '';

  if (defined $row->{qualifiers}) {
    $qualifier_string = join ', ', @{$row->{qualifiers}};
  }

  return {
    annotation_id => $row->{annotation_id},
    gene_identifier => $gene->{identifier},
    gene_name => $gene->{name} || '',
    gene_name_or_identifier =>
      $gene->{name} || $gene->{identifier},
    gene_product => $gene->{product} || '',
    allele_display_name => $allele_display_name,
    expression_level => $row->{expression} // '',
    conditions => $conditions_string,
    qualifiers => $qualifier_string,
    annotation_type => $ontology_name,
    term_ontid => $term_ontid,
    term_name => $term_name,
    evidence_code => $evidence_code,
    with_or_from_identifier => $row->{with} // $row->{from},
    with_or_from_display_name => $row->{with} // $row->{from},
    taxonid => $gene->{organism_taxonid},
    status => 'existing',
    is_not => $is_not,
  };
}

=head2 get_existing_ontology_annotations

 Usage   :
   my ($all_annotations_count, $annotations) =
     Canto::Curs::Utils::get_existing_ontology_annotations($config, $options);
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
      my $res = _process_existing_db_ontology($ontology_lookup, $_);
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
  my $ontology_lookup = shift;
  my $row = shift;

  my $gene = $row->{gene};
  my $interacting_gene = $row->{interacting_gene};
  my $publication = $row->{publication};

  return {
    gene_identifier => $gene->{identifier},
    gene_display_name => $gene->{name} // $gene->{identifier},
    gene_taxonid => $gene->{taxonid},
    publication_uniquename => $publication->{uniquename},
    evidence_code => $row->{evidence_code},
    interacting_gene_identifier => $interacting_gene->{identifier},
    interacting_gene_display_name =>
      $interacting_gene->{name} // $interacting_gene->{identifier},
    interacting_gene_taxonid => $interacting_gene->{taxonid},
    status => 'existing',
  };
}

=head2 get_existing_interaction_annotations

 Usage   :
   my ($all_existing_annotations_count, $annotations) =
      Canto::Curs::Utils::get_existing_interaction_annotations($config, $options);
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
      my $res = _process_interaction($annotation_lookup, $_);
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
     Canto::Curs::Utils::get_existing_annotations($config, $options);
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
  my $options = shift;

  my $annotation_type_category =
    $config->{annotation_types}->{$options->{annotation_type_name}}->{category};

  if ($annotation_type_category eq 'ontology') {
    return get_existing_ontology_annotations($config, $options);
  } else {
    return get_existing_interaction_annotations($config, $options);
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
  my $arg_options = shift;

  my $count = 0;

  for my $annotation_type (@{$config->{annotation_type_list}}) {
    my $options = clone $arg_options;
    $options->{annotation_type_name} = $annotation_type->{name};
    my ($all_annotations_count, $annotations) =
      Canto::Curs::Utils::get_existing_annotations($config, $options);
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

  my $state = Canto::Curs::State->new(config => $config);

  my $iter = Canto::Track::curs_iterator($config, $track_schema);
  while (my ($curs, $cursdb) = $iter->()) {
    $state->store_statuses($cursdb);
  }
}

=head2 make_allele_display_name

 Usage   : $dis_name = make_allele_display_name($name, $description);
 Function: make an allele display name from a name and description
 Args    : $name - the allele name (can be undef)
           $description - the allele description (can be undef)
 Returns : a display name of the form "name(description)"

=cut
sub make_allele_display_name
{
  my $name = shift // 'noname';
  my $description = shift // 'unknown';

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
