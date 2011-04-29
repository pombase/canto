use strict;
use warnings;
use Test::More tests => 17;

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
  my $pub = $schema->resultset('Pub')->first();
  my $options = { pub_uniquename => $pub->uniquename(),
                  ontology_name => 'biological_process' };
  my @annotations =
    PomCur::Curs::Utils::get_existing_annotations($config, $options);

  is (@annotations, 2);
}
