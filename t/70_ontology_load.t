use strict;
use warnings;
use Test::More tests => 13;

use Data::Compare;

use PomCur::TestUtil;
use PomCur::Track::OntologyLoad;
use PomCur::Track::OntologyIndex;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('empty_db', { copy_ontology_index => 0 });

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @loaded_cvterms = $schema->resultset('Cvterm')->all();

is (@loaded_cvterms, 6);

my $test_ontology_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_go_obo_file};

my $ontology_index = PomCur::Track::OntologyIndex->new(config => $config);
$ontology_index->initialise_index();
my $ontology_load = PomCur::Track::OntologyLoad->new(schema => $schema);
$ontology_load->load($test_ontology_file, $ontology_index);
$ontology_index->finish_index();

@loaded_cvterms = $schema->resultset('Cvterm')->all();

is(@loaded_cvterms, 23);

ok(grep {
  $_->name() eq 'regulation of transmembrane transport'
} @loaded_cvterms);

ok(grep {
  $_->name() eq 'negative regulation of transmembrane transport' &&
    $_->cvtermsynonym_cvterms()->first()->synonym() eq
      'down regulation of transmembrane transport'
} @loaded_cvterms);

my $ontology_name = 'biological_process';
my $hits =
  $ontology_index->lookup($ontology_name, 'transmembrane transport()\:-', 100);

my $num_hits = $hits->length();

for (my $i = 0; $i < $num_hits; $i++) {
  my $doc = $hits->doc($i);
  my $cv_name = $doc->get('cv_name');

  is($cv_name, $ontology_name);
}

is($hits->doc(0)->get('name'), 'transmembrane transport');
is($hits->doc(1)->get('name'), 'protein transmembrane transport');
