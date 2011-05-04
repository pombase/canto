use strict;
use warnings;
use Test::More tests => 17;
use Test::MockObject;

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
  my $cv_name = 'biological_process';
  my $cv = $schema->find_with_type('Cv', { name => $cv_name });
  my $pub = $schema->resultset('Pub')->first();

  my $mock = Test::MockObject->new();

  $mock->fake_module('PomCur::ChadoDB');
  $mock->fake_new('PomCur::ChadoDB');

  my $find_with_type_mock =
    sub {
      if ($_[0] eq 'Pub') {
        return $pub;
      } else {
        return $cv;
      }
    };
  $mock->mock('find_with_type', $find_with_type_mock);

  my $resultset_mock =
    sub {
      my $type = $_[1];
      my $mock_rs = Test::MockObject->new();
      my $search_mock =
        sub {
          my $single_mock =
            sub {
              return 0;
            };
          $search_mock->mock('single', $single_mock);

          my @feature_cvterms
        };
      $mock_rs->mock('search', $search_mock);
    };
  $mock->mock('resultset', $resultset_mock);

  my $options = { pub_uniquename => $pub->uniquename(),
                  ontology_name => $cv_name };
  my @annotations =
    PomCur::Curs::Utils::get_existing_annotations($config, $options);

  is (@annotations, 2);
}
