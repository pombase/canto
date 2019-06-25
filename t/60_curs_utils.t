use strict;
use warnings;
use Test::More tests => 122;
use Test::Deep;

use Canto::TestUtil;
use Canto::Curs::Utils;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $schema = $test_util->track_schema();

my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

is(Canto::Curs::Utils::make_allele_display_name($config,
   'test-1', 'some_desc', 'some_type'),
   'test-1(some_desc)');
is(Canto::Curs::Utils::make_allele_display_name($config,
   'testdelta', 'deletion', 'deletion'),
   'testdelta');
is(Canto::Curs::Utils::make_allele_display_name($config,
   'testdelta', undef, 'deletion'),
   'testdelta');
is(Canto::Curs::Utils::make_allele_display_name($config,
   'testdelta', 'deletion', 'deletion'),
   'testdelta');
is(Canto::Curs::Utils::make_allele_display_name($config,
   'testdelta', 'deletion', 'wild_type'),
   'testdelta(deletion)');
is(Canto::Curs::Utils::make_allele_display_name($config,
   'test+', '', 'wild type'),
   'test+');
is(Canto::Curs::Utils::make_allele_display_name($config,
   'test+', 'wildtype', 'wild_type'),
   'test+');
is(Canto::Curs::Utils::make_allele_display_name($config,
   'test+', 'deletion', 'wild_type'),
   'test+(deletion)');
is(Canto::Curs::Utils::make_allele_display_name($config,
   'test+', undef, 'deletion'),
   'test+(deletion)');

sub check_new_annotations
{
  my $exp_term_ontid = shift // 'GO:0055085';

  {
    my ($completed_count, $annotations_ref) =
      Canto::Curs::Utils::get_annotation_table($config, $curs_schema,
                                                'biological_process');

    my @annotations = @$annotations_ref;

    is (@annotations, 2);

    is ($annotations[0]->{gene_identifier}, 'SPAC27D7.13c');
    is ($annotations[0]->{term_ontid}, $exp_term_ontid);
    is ($annotations[0]->{taxonid}, '4896');
    like ($annotations[0]->{creation_date}, qr/\d+-\d+-\d+/);
    is ($annotations[0]->{gene_synonyms_string}, 'SPAC637.01c');
  }

  {
    my ($completed_count, $annotations_ref) =
      Canto::Curs::Utils::get_annotation_table($config, $curs_schema,
                                                'genetic_interaction');

    my @annotations = @$annotations_ref;

    is (@annotations, 2);

    my $interacting_gene_count = 0;

    for my $annotation (@annotations) {
      is ($annotation->{genotype_a_display_name}, 'SPCC63.05delta ssm4KE');
      is ($annotation->{genotype_a_taxonid}, '4896');
      is ($annotation->{publication_uniquename}, 'PMID:19756689');
      if ($annotation->{evidence_code} eq 'Synthetic Haploinsufficiency') {
        $interacting_gene_count++
      } else {
        if ($annotation->{evidence_code} eq 'Far Western') {
          $interacting_gene_count++
        } else {
          fail ("unknown interacting gene");
        }
      }
    }

    is ($interacting_gene_count, 2);
  }

  {
    my ($completed_count, $annotations_ref) =
      Canto::Curs::Utils::get_annotation_table($config, $curs_schema,
                                               'phenotype');

    my @annotations =
      sort { $a->{genotype_identifier} cmp $b->{genotype_identifier} } @$annotations_ref;

    cmp_deeply(\@annotations,
             [
               {
                 'genotype_id' => 1,
                 'extension' => [],
                 'status' => 'new',
                 'term_suggestion_name' => undef,
                 'term_suggestion_definition' => undef,
                 'with_gene_id' => undef,
                 'curator' => 'Some Testperson <some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org>',
                 'genotype_identifier' => 'aaaa0007-genotype-test-1',
                 'taxonid' => undef,
                 'organism' => {
                   'pathogen_or_host' => 'unknown',
                   'taxonid' => '4896',
                   'full_name' => 'Schizosaccharomyces pombe',
                   scientific_name => 'Schizosaccharomyces pombe',
                   'common_name' => 'fission yeast',
                 },
                 'strain_name' => undef,
                 'conditions' => [
                   {
                     'term_id' => 'PECO:0000137',
                     'name' => 'glucose rich medium'
                   },
                   {
                     'name' => 'rich medium'
                   }
                 ],
                 'term_ontid' => 'FYPO:0000013',
                 'with_or_from_identifier' => undef,
                 'term_name' => 'T-shaped cells',
                 'needs_with' => undef,
                 'completed' => 1,
                 'annotation_type' => 'phenotype',
                 'annotation_id' => 6,
                 'is_not' => JSON::false,
                 'evidence_code' => 'Epitope-tagged protein immunolocalization experiment data',
                 'annotation_type_abbreviation' => '',
                 'annotation_type_display_name' => 'phenotype',
                 'genotype_name' => "SPCC63.05delta ssm4KE",
                 'genotype_background' => "h+",
                 'is_obsolete_term' => 0,
                 'creation_date_short' => '20100102',
                 'with_or_from_display_name' => undef,
                 'qualifiers' => [],
                 'creation_date' => '2010-01-02',
                 'submitter_comment' => undef,
                 'publication_uniquename' => 'PMID:19756689',
                 'feature_type' => 'genotype',
                 'feature_id' => 1,
                 'genotype_display_name' => 'SPCC63.05delta ssm4KE',
                 'feature_display_name' => 'SPCC63.05delta ssm4KE',
                 'alleles' => [
                   {
                     'description' => 'deletion',
                     'name' => 'ssm4delta',
                     'gene_id' => 2,
                     'primary_identifier' => 'SPAC27D7.13c:aaaa0007-1',
                     'type' => 'deletion',
                     'expression' => undef,
                     'allele_id' => 1,
                     'display_name' => 'ssm4delta',
                     'long_display_name' => 'ssm4delta',
                     'gene_display_name' => 'ssm4',
                     'synonyms' => [],
                   },
                   {
                     'gene_id' => 4,
                     'name' => 'SPCC63.05delta',
                     'description' => 'deletion',
                     'type' => 'deletion',
                     'expression' => undef,
                     'allele_id' => 5,
                     'primary_identifier' => 'SPCC63.05:aaaa0007-1',
                     'display_name' => 'SPCC63.05delta',
                     'long_display_name' => 'SPCC63.05delta',
                     'gene_display_name' => 'SPCC63.05',
                     'synonyms' => [],
                   }
                 ],
                 checked => 'no',
               },
               {
                 'publication_uniquename' => 'PMID:19756689',
                 'feature_type' => 'genotype',
                 'feature_id' => 2,
                 'genotype_display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
                 'feature_display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
                 'is_not' => JSON::false,
                 'evidence_code' => 'Co-immunoprecipitation experiment',
                 'annotation_type_abbreviation' => '',
                 'annotation_type_display_name' => 'phenotype',
                 'organism' => {
                   'pathogen_or_host' => 'unknown',
                   'taxonid' => '4896',
                   'full_name' => 'Schizosaccharomyces pombe',
                   scientific_name => 'Schizosaccharomyces pombe',
                   'common_name' => 'fission yeast',
                 },
                 'strain_name' => undef,
                 'genotype_name' => undef,
                 'genotype_background' => undef,
                 'is_obsolete_term' => 0,
                 'creation_date_short' => '20100102',
                 'with_or_from_display_name' => undef,
                 'qualifiers' => [],
                 'submitter_comment' => undef,
                 'creation_date' => '2010-01-02',
                 'taxonid' => undef,
                 'conditions' => [],
                 'term_ontid' => 'FYPO:0000017',
                 'with_or_from_identifier' => undef,
                 'term_name' => 'elongated cell',
                 'needs_with' => undef,
                 'completed' => 1,
                 'annotation_id' => 7,
                 'annotation_type' => 'phenotype',
                 'genotype_id' => 2,
                 'extension' => [],
                 'status' => 'new',
                 'term_suggestion_name' => undef,
                 'term_suggestion_definition' => undef,
                 'with_gene_id' => undef,
                 'curator' => 'Some Testperson <some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org>',
                 'genotype_identifier' => 'aaaa0007-genotype-test-2',
                 'alleles' => [
                   {
                     'primary_identifier' => 'SPAC27D7.13c:aaaa0007-3',
                     'expression' => 'Knockdown',
                     'allele_id' => 3,
                     'type' => 'partial deletion, nucleotide',
                     'description' => 'del_100-200',
                     'name' => 'ssm4-D4',
                     'gene_id' => 2,
                     'display_name' => 'ssm4-D4(del_100-200)',
                     'long_display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
                     'gene_display_name' => 'ssm4',
                     'synonyms' => [{ edit_status => 'new', synonym => 'ssm4-c1'}],
                   }
                 ],
                 checked => 'no',
               }
             ]);
  }

  my @annotation_type_list = @{$config->{annotation_type_list}};

  my $genotype_count = 0;

  for my $annotation_type_config (@annotation_type_list) {
    my ($completed_count, $annotations_ref) =
      Canto::Curs::Utils::get_annotation_table($config, $curs_schema,
                                                $annotation_type_config->{name});

    my @annotations = @$annotations_ref;

    for my $annotation_row (@annotations) {
      ok (length $annotation_row->{annotation_type} > 0);
      ok (length $annotation_row->{evidence_code} > 0);

      if ($annotation_type_config->{category} eq 'ontology') {
        ok (length $annotation_row->{term_ontid} > 0);
        ok (length $annotation_row->{term_name} > 0);

        if ($annotation_type_config->{feature_type} eq 'genotype') {
          ok (length $annotation_row->{genotype_identifier} > 0);
          $genotype_count++;
        } else {
          ok (length $annotation_row->{gene_name_or_identifier} > 0);
        }
      }
    }
  }
  ok ($genotype_count > 0);

}

check_new_annotations();

# change an ontid to an alt_id
my $an_rs = $curs_schema->resultset('Annotation');
my $dummy_alt_id = "GO:123456789";
my $made_alt_id_change = 0;

while (defined (my $an = $an_rs->next())) {
  my $data = $an->data();

  if (defined $data->{term_ontid} && $data->{term_ontid} eq "GO:0055085") {
    $made_alt_id_change = 1;
    $data->{term_ontid} = $dummy_alt_id;
    $an->data($data);
    $an->update();
  }
}

ok($made_alt_id_change);

check_new_annotations($dummy_alt_id);


{
  my $options = { pub_uniquename => 'PMID:19756689',
                  annotation_type_name => 'cellular_component',
                };
  my ($all_annotation_count, $annotations) =
    Canto::Curs::Utils::get_existing_annotations($config, $curs_schema, $options);

  is (@$annotations, 1);
  cmp_deeply($annotations->[0],
             {
               'taxonid' => '4896',
               'annotation_type' => 'cellular_component',
               'term_ontid' => 'GO:0030133',
               'term_name' => 'transport vesicle',
               'with_or_from_identifier' => undef,
               'gene_identifier' => 'SPBC12C2.02c',
               'gene_name_or_identifier' => 'ste20',
               'gene_product_form_id' => 'PR:000027576',
               'conditions' => [],
               'qualifiers' => [],
               'evidence_code' => 'IMP',
               'annotation_id' => 1,
               'gene_name' => 'ste20',
               'gene_product' => '',
               'gene_id' => undef,
               'feature_id' => undef,
               'feature_display_name' => 'ste20',
               'feature_type' => 'gene',
               'is_not' => JSON::false,
               'status' => 'existing',
               'with_or_from_display_name' => 'PomBase:SPBC2G2.01c',
               'with_or_from_identifier' => 'PomBase:SPBC2G2.01c',
               'with_gene_id' => undef,
               'extension' => undef,
            });
}

{
  my $options = { pub_uniquename => 'PMID:19756689',
                  annotation_type_name => 'biological_process',
                };
  my ($all_annotation_count, $annotations) =
    Canto::Curs::Utils::get_existing_ontology_annotations ($config, $curs_schema, $options);

  is (@$annotations, 1);
  cmp_deeply($annotations->[0],
             {
               'taxonid' => '4896',
               'annotation_type' => 'biological_process',
               'term_ontid' => 'GO:0006810',
               'term_name' => 'transport',
               'with_or_from_identifier' => undef,
               'gene_identifier' => 'SPBC12C2.02c',
               'gene_name_or_identifier' => 'ste20',
               'gene_product_form_id' => undef,
               'gene_id' => undef,
               'qualifiers' => [],
               'conditions' => [],
               'evidence_code' => 'UNK',
               'annotation_id' => 2,
               'gene_name' => 'ste20',
               'gene_product' => '',
               'feature_id' => undef,
               'feature_display_name' => 'ste20',
               'feature_type' => 'gene',
               'is_not' => JSON::true,
               'status' => 'existing',
               'with_or_from_display_name' => undef,
               'with_or_from_identifier' => undef,
               'with_gene_id' => undef,
               'extension' =>
                 [
                   [
                     {
                       'relation' => 'requires_direct_regulator',
                       'rangeValue' => 'CONFIGURE_IN_CANTO_DEPLOY.YAML:cdc11'
                     }
                   ]
                 ],
           });
}


# test existing phenotype annotation
{
  my $options = { pub_uniquename => 'PMID:19756689',
                  annotation_type_name => 'phenotype',
                };
  my ($all_annotation_count, $annotations) =
    Canto::Curs::Utils::get_existing_ontology_annotations ($config, $curs_schema, $options);

  is (@$annotations, 1);
  cmp_deeply($annotations->[0],
             {
               'term_name' => 'sensitive to cycloheximide',
               'feature_id' => undef,
               'is_not' => bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' ),
               'genotype_name' => 'cdc11-33 ssm4delta',
               'genotype_identifier' => 'aaaa0007-test-genotype-3',
               'alleles' => [
                 {
                   'type' => 'unknown',
                   'gene_display_name' => 'cdc11',
                   'taxonid' => '4896',
                   'primary_identifier' => 'SPCC1739.11c:allele-1',
                   'long_display_name' => 'cdc11-33(unknown)[Knockdown]',
                   'description' => 'unknown',
                   'name' => 'cdc11-33',
                   'gene_id' => 4,
                   expression => 'Knockdown',
                 },
                 {
                   'long_display_name' => 'ssm4delta(deletion)',
                   'primary_identifier' => 'SPAC27D7.13c:allele-1',
                   'name' => 'ssm4delta',
                   'description' => 'deletion',
                   'gene_display_name' => 'ssm4',
                   'type' => 'deletion',
                   'taxonid' => '4896',
                   'gene_id' => 15,
                   expression => undef,
                 }
               ],
               'feature_type' => 'genotype',
               'annotation_id' => 3,
               'term_ontid' => 'FYPO:0000104',
               'qualifiers' => [],
               'conditions' => [],
               'status' => 'existing',
               'feature_display_name' => 'cdc11-33 ssm4delta',
               'genotype_id' => undef,
               'evidence_code' => 'UNK',
               'genotype_name_or_identifier' => 'cdc11-33 ssm4delta',
               'annotation_type' => 'phenotype',
               'extension' => undef,
             });
}

sub _test_interactions
{
  my ($expected_count, @annotations) = @_;

  is (@annotations, $expected_count);
  cmp_deeply($annotations[0],
             {
               'gene_identifier' => 'SPBC12C2.02c',
               'gene_display_name' => 'ste20',
               'gene_taxonid' => '4896',
               'gene_id' => undef,
               'interacting_gene_identifier' => 'SPCC1739.11c',
               'interacting_gene_display_name' => 'cdc11',
               'interacting_gene_taxonid' => '4896',
               'interacting_gene_id' => undef,
               'evidence_code' => 'Phenotypic Enhancement',
               'publication_uniquename' => 'PMID:19756689',
               'status' => 'existing',
               'annotation_type' => 'genetic_interaction',
           });
}

{
  my $options = { pub_uniquename => 'PMID:19756689',
                  annotation_type_name => 'genetic_interaction',
                  annotation_type_category => 'interaction', };
  my ($all_interactions_count, $annotations) =
    Canto::Curs::Utils::get_existing_interaction_annotations ($config, $curs_schema, $options);

  _test_interactions(2, @$annotations);
}

{
  my $options = { pub_uniquename => 'PMID:19756689',
                  annotation_type_name => 'genetic_interaction',
                  annotation_type_category => 'interaction',
                  max_results => 1, };
  my ($all_interactions_count, $annotations) =
    Canto::Curs::Utils::get_existing_interaction_annotations ($config, $curs_schema, $options);

  _test_interactions(1, @$annotations);
}

{
  my $options = { pub_uniquename => 'PMID:19756689',
                  annotation_type_name => 'genetic_interaction',
                  annotation_type_category => 'interaction', };
  my ($all_interactions_count, $annotations) =
    Canto::Curs::Utils::get_existing_annotations($config, $curs_schema, $options);

  _test_interactions(2, @$annotations);
}
