package Canto::Chado::OntologyAnnotationLookup;

=head1 NAME

Canto::Chado::OntologyAnnotationLookup - Code for looking up ontology
    annotation in a ChadoDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Chado::OntologyAnnotationLookup

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

use Carp;
use Moose;

use CHI;

use feature "state";

use Canto::Cache;

with 'Canto::Role::Configurable';
with 'Canto::Chado::ChadoLookup';

has cache => (is => 'ro', init_arg => undef, lazy_build => 1);

sub _build_cache
{
  my $self = shift;

  my $cache = Canto::Cache::get_cache($self->config(), __PACKAGE__);

  return $cache;
}

sub _get_taxonid
{
  my $cache = shift;
  my $organism = shift;

  if (exists $cache->{$organism->organism_id()}) {
    return $cache->{$organism->organism_id()};
  } else {
    my $prop = $organism->organismprops()
      ->search({ 'type.name' => 'taxon_id' }, { join => 'type' })->first();

    my $taxonid = $prop->value();

    die "no taxon_id for ", $organism->full_name() unless defined $taxonid;

    $cache->{$organism->organism_id()} = $taxonid;
    return $taxonid;
  }
}

# if the $feature is an mRNA, return it's gene feature, otherwise return
# the $feature
sub _gene_of_feature
{
  my $self = shift;
  my $feature = shift;

  my $mrna_cvterm = $self->schema()->get_cvterm('sequence', 'mRNA');

  if ($feature->type_id() == $mrna_cvterm->cvterm_id()) {
    my $gene_cvterm = $self->schema()->get_cvterm('sequence', 'gene');
    my $part_of_cvterm = $self->schema()->get_cvterm('relationship', 'part_of');

    return $feature->feature_relationship_subjects()
                   ->search({ 'me.type_id' => $part_of_cvterm->cvterm_id() })
                   ->search_related('object')
                   ->search({
                     'object.type_id' => $gene_cvterm->cvterm_id()
                   })->single();
  } else {
    return $feature;
  }
}

sub _get_prop_type_cvterm_id
{
  my $self = shift;
  my $schema = $self->schema();
  my $type_cv = shift;
  my $type_name = shift;

  my $cvterm =
    $schema->resultset('Cvterm')
           ->search({ cv_id => $type_cv->cv_id(),
                      name => $type_name })
           ->single();

  if (defined $cvterm) {
    return $cvterm->cvterm_id();
  } else {
    return undef;
  }
}

=head2

 Usage   : my ($all_annotations_count, $res) =
             Canto::Chado::OntologyAnnotationLookup($options);
 Function: lookup ontology annotation in a Chado database
 Args    : $options->{pub_uniquename} - the identifier of the publication,
               usually the PubMed ID to get annotations for
           $options->{gene_identifier} - the gene identifier to use to constrain
               the search; only annotations for the gene are returned (optional)
           $options->{ontology_name} - the ontology name to use to restrict the
               search; only annotations using terms from this ontology are
               returned (optional)
 Returns : $all_annotations_count - the total matching annotations, ignoring
                                    max_results
           $res - an array reference of at most max_results annotation results:
            [ {
              gene => {
                identifier => "SPAC22F3.13",
                name => 'tsc1',
                organism_taxonid => 4896
              },
              ontology_term => {
                ontology_name => 'molecular_function',
                term_name => 'regulation of conjugation ...',
                ontid => 'GO:0031137',
              },
              publication => {
                uniquename => 'PMID:10467002',
              },
              evidence_code => 'IMP',
              annotation_id => ....
            }, ... ]
          - where annotation_id is a unique ID for this annotation

=cut

sub lookup
{
  my $self = shift;
  my $args_ref = shift;
  my %args = %{$args_ref};

  my $pub_uniquename = $args{pub_uniquename};
  my $gene_identifier = $args{gene_identifier};
  my $ontology_name = $args{ontology_name};
  my $max_results = $args{max_results} // 0;

  die "no ontology_name" unless defined $ontology_name;

  my $cache_key;

  if (defined $gene_identifier) {
    $cache_key = "$pub_uniquename!$gene_identifier!$ontology_name!$max_results";
  } else {
    $cache_key = "$pub_uniquename!$ontology_name!$max_results";
  }

  my $cached_value = $self->cache->get($cache_key);

  if (defined $cached_value) {
use Data::Dumper;
warn qq(returning cached result from Chado ontology lookup using key "$cache_key": ), Dumper([$cached_value]);

    return @{$cached_value};
  }

  my %db_ontology_names = %{$self->config()->{chado}->{ontology_cv_names}};

  my $db_ontology_name;
  if (exists $db_ontology_names{$ontology_name}) {
    $db_ontology_name = $db_ontology_names{$ontology_name};
  } else {
    $db_ontology_name = $ontology_name;
  }

  my $chado_conf = $self->config()->{chado};
  my $evidence_codes_to_ignore_conf =
    $chado_conf->{annotation_lookup}->{evidence_codes_to_ignore};
  my @evidence_codes_to_ignore = ();
  if (defined $evidence_codes_to_ignore_conf) {
    @evidence_codes_to_ignore = @$evidence_codes_to_ignore_conf
  }

  my $schema = $self->schema();

  my $pub = $schema->resultset('Pub')->find({ uniquename => $pub_uniquename });

  my $ret_val = undef;

  if (defined $pub) {
    my $prop_type_cv =
      $schema->find_with_type('Cv', name => 'feature_cvtermprop_type');
    my @prop_type_names = qw[evidence with from condition expression qualifier];
    my %prop_cvterm_ids = ();
    for my $prop_type_name (@prop_type_names) {
      $prop_cvterm_ids{$prop_type_name} =
        $self->_get_prop_type_cvterm_id($prop_type_cv, $prop_type_name);
    }
    my $cv = $schema->resultset('Cv')->find({ name => $db_ontology_name });

    if (!defined $cv) {
      warn "no Cv found with name: $db_ontology_name\n";
      return ();
    }

    my $annotation_extension_cv_name = $chado_conf->{ontology_cv_names}->{annotation_extension};
    my $ext_cv = $schema->resultset('Cv')->find({ name => $annotation_extension_cv_name });

    my $is_a_term = $schema->resultset('Cvterm')->find({ name => 'is_a' });

    my $is_a_rs =
      $schema->resultset('CvtermRelationship')->search(
        {
          type_id => $is_a_term->cvterm_id(),
          'object.cv_id' => $cv->cv_id(),
        },
        {
          join => 'object',
        }
      );

    my $constraint_and_bits = {
      -and => {
        pub_id => $pub->pub_id(),
        -or => {
          'cvterm.cv_id' => $cv->cv_id(),
           -and => {
             'cvterm.cv_id' => $ext_cv->cv_id(),
             'me.cvterm_id' => {
               -in => $is_a_rs->get_column('subject_id')->as_query(),
             },
           }
        }
      }
    };
    if (defined $gene_identifier) {
      my $transcript_params =
        { where => "me.feature_id in (select subject_id from feature_relationship r, cvterm t, feature objf " .
          "where r.type_id = t.cvterm_id and r.object_id = objf.feature_id " .
          "and objf.uniquename = '$gene_identifier')" };
      my $transcript_rs =
        $schema->resultset('Feature')->search({}, $transcript_params);

      # jump through hoops to query genes or transcripts
      $constraint_and_bits->{'-or'} =
        {
          'feature.uniquename' => $gene_identifier,
          'feature.feature_id' => {
            -in => $transcript_rs->get_column('feature_id')->as_query()
          }
        };
    }

    my $constraint = { -and => [%$constraint_and_bits] };

    my $options = { prefetch => [ { feature => 'organism' },
                                  { cvterm => [ 'cv', { dbxref => 'db' } ] } ],
                    join => ['cvterm', 'feature'] };
    my $rs = $schema->resultset('FeatureCvterm')->search($constraint, $options);
    my $taxonid_cache = {};

    my $all_annotations_count = $rs->count();

    if ($max_results > 0) {
      $rs = $rs->search({}, { rows => $max_results });
    }

    my @res = ();

    while (defined (my $row = $rs->next())) {
      my $feature = $self->_gene_of_feature($row->feature());
      my $cvterm = $row->cvterm();
      my $organism = $feature->organism();
      my @props = $row->feature_cvtermprops()->all();
      my %prop_type_values = (evidence => 'Unknown',
                              with => undef,
                              from => undef,
                              expression => undef,
                              qualifier => [],
                              condition => [],
                              );
      for my $prop (@props) {
        for my $prop_type_name (@prop_type_names) {
          if (defined $prop_cvterm_ids{$prop_type_name} &&
              $prop_cvterm_ids{$prop_type_name} == $prop->type_id()) {
            if (ref $prop_type_values{$prop_type_name}) {
              push @{$prop_type_values{$prop_type_name}}, $prop->value();
            } else {
              $prop_type_values{$prop_type_name} = $prop->value();
            }
          }
        }
      }

      $prop_type_values{evidence} //= 'Unknown';

      $prop_type_values{evidence} =~ s/\s+with\s+.*//;
      my $evidence = $prop_type_values{evidence};
      my $evidence_code =
        $self->config()->{evidence_types_by_name}->{lc $evidence};

      if (grep { $_ eq $evidence } @evidence_codes_to_ignore or
          grep { $_ eq $evidence_code } @evidence_codes_to_ignore) {
        # adjust the total, but this is dodgy as the total will be too high if
        # there are more than $max_results results
        $all_annotations_count--;
        next;
      }

      my $real_cvterm;

      if ($cvterm->cv_id() == $ext_cv->cv_id()) {
        $real_cvterm =
          $cvterm->cvterm_relationship_subjects()
                 ->search({ type_id => $is_a_term->cvterm_id() })
                 ->first()
                 ->object();
      } else {
        $real_cvterm = $cvterm;
      }

      my $new_res =
        {
          ontology_term => {
            ontology_name => $real_cvterm->cv()->name(),
            term_name => $real_cvterm->name(),
            ontid => $real_cvterm->db_accession(),
          },
          is_not => $row->is_not(),
          with => $prop_type_values{with},
          from => $prop_type_values{from},
          publication => {
            uniquename => $pub_uniquename,
          },
          conditions => $prop_type_values{condition},
          evidence_code => $evidence_code,
          expression => $prop_type_values{expression},
          qualifiers => $prop_type_values{qualifier},
          annotation_id => $row->feature_cvterm_id(),
        };

      my $taxonid = _get_taxonid($taxonid_cache, $organism);

      if ($feature->type()->name() eq 'allele') {
        my $feature_rels = $feature->feature_relationship_subjects();
        my $gene;
        while (defined (my $rel = $feature_rels->next())) {
          if ($rel->type()->name() eq 'instance_of') {
            $gene = $rel->object();
          }
        }
        if (defined $gene) {
          $new_res->{gene} = {
            identifier => $gene->uniquename(),
            name => $gene->name(),
            organism_taxonid => $taxonid,
          };
        } else {
          $new_res->{gene} = {
            identifier => 'not_found',
            organism_taxonid => $taxonid,
          },
        }
        my $allele_description_prop =
          $feature->featureprops()
          ->search({ 'type.name' => 'description' }, { join => 'type' })->first();
        my $allele_description = undef;
        if (defined $allele_description_prop) {
          $allele_description = $allele_description_prop->value();
        }

        $new_res->{allele} = {
          identifier => $feature->uniquename(),
          name => $feature->name(),
          description => $allele_description,
          organism_taxonid => $taxonid,
        };
      } else {
        $new_res->{gene} = {
          identifier => $feature->uniquename(),
          name => $feature->name(),
          organism_taxonid => $taxonid,
        };
      }

      if ($real_cvterm != $cvterm) {
        $new_res->{ontology_term}->{extension_term_name} = $cvterm->name();
      }

      push @res, $new_res;
    }

    $ret_val = [$all_annotations_count, \@res];
  } else {
    $ret_val = [0, []];
  }

use Data::Dumper;
warn qq(adding result to cache in Chado ontology lookup with cache key "$cache_key": ),
  Dumper([$ret_val]);

  $self->cache()->set($cache_key, $ret_val, "2 hours");

  return @$ret_val;
}

1;
