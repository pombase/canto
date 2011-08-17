use strict;
use warnings;
use Test::More tests => 23;
use Test::Deep;

use PomCur::TestUtil;
use PomCur::Curs::Utils;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $schema = $test_util->track_schema();

my $curs_schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0007');

{
  my ($completed_count, $annotations_ref) =
    PomCur::Curs::Utils::get_annotation_table($config, $curs_schema,
                                              'biological_process');

  my @annotations = @$annotations_ref;

  is (@annotations, 2);

  is ($annotations[0]->{gene_identifier}, 'SPAC27D7.13c');
  is ($annotations[0]->{term_ontid}, 'GO:0055085');
  is ($annotations[0]->{taxonid}, '4896');
  like ($annotations[0]->{creation_date}, qr/\d+-\d+-\d+/);
  is ($annotations[0]->{gene_synonyms_string}, 'SPAC637.01c');
}

{
  my ($completed_count, $annotations_ref) =
    PomCur::Curs::Utils::get_annotation_table($config, $curs_schema,
                                              'genetic_interaction');

  my @annotations = @$annotations_ref;

  is (@$annotations_ref, 2);

  for my $annotation (@annotations) {
    is ($annotation->{gene_identifier}, 'SPCC63.05');
    is ($annotation->{gene_taxonid}, '4896');
    is ($annotation->{publication_uniquename}, 'PMID:19756689');
    is ($annotation->{evidence_code}, 'Synthetic Haploinsufficiency');
  }

  is ($annotations[0]->{interacting_gene_identifier}, 'SPBC14F5.07');
  is ($annotations[1]->{interacting_gene_identifier}, 'SPAC27D7.13c');
}

{
  my $options = { pub_uniquename => 'PMID:20519959',
                  annotation_type_name => 'biological_process',
                };
  my @annotations =
    PomCur::Curs::Utils::get_existing_ontology_annotations ($config, $options);

  is (@annotations, 1);
  cmp_deeply($annotations[0],
             {
               'taxonid' => '4896',
               'annotation_type' => 'biological_process',
               'term_ontid' => 'GO:0006810',
               'term_name' => 'transport',
               'with_or_from_identifier' => undef,
               'gene_identifier' => 'SPBC12C2.02c',
               'gene_name_or_identifier' => 'ste20',
               'qualifier' => '',
               'evidence_code' => 'IMP',
               'annotation_id' => 1,
               'gene_name' => 'ste20',
               'gene_product' => '',
               'with_or_from_display_name' => 'GeneDB_Spombe:SPBC2G2.01c',
               'with_or_from_identifier' => 'GeneDB_Spombe:SPBC2G2.01c',
             });
}

sub _test_interactions
{
  my @annotations = @_;

  is (@annotations, 1);
  cmp_deeply($annotations[0],
             {
               'gene_identifier' => 'SPBC12C2.02c',
               'gene_display_name' => 'ste20',
               'gene_taxonid' => '4896',
               'interacting_gene_identifier' => 'SPCC1739.11c',
               'interacting_gene_display_name' => 'cdc11',
               'interacting_gene_taxonid' => '4896',
               'evidence_code' => 'Phenotypic Enhancement',
               'publication_uniquename' => 'PMID:20519959',
             });
}

{
  my $options = { pub_uniquename => 'PMID:20519959',
                  annotation_type_name => 'genetic_interaction',
                  annotation_type_category => 'interaction', };
  my @annotations =
    PomCur::Curs::Utils::get_existing_interaction_annotations ($config, $options);

  _test_interactions(@annotations);
}

{
  my $options = { pub_uniquename => 'PMID:20519959',
                  annotation_type_name => 'genetic_interaction',
                  annotation_type_category => 'interaction', };
  my @annotations =
    PomCur::Curs::Utils::get_existing_annotations($config, $options);

  _test_interactions(@annotations);
}
