use strict;
use warnings;
use Test::More tests => 5;

use Data::Compare;

use PomCur::TestUtil;
use PomCur::Track::OntologyLoad;
use PomCur::Track::OntologyIndex;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('empty_db', { copy_ontology_index => 0 });

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @loaded_cvterms = $schema->resultset('Cvterm')->all();

is (@loaded_cvterms, 0);

my $test_ontology_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_go_obo_file};

my $ontology_index = PomCur::Track::OntologyIndex->new(config => $config);
$ontology_index->initialise_index();
my $ontology_load = PomCur::Track::OntologyLoad->new(schema => $schema);
$ontology_load->load($test_ontology_file, $ontology_index);
$ontology_index->finish_index();

@loaded_cvterms = $schema->resultset('Cvterm')->all();

is(@loaded_cvterms, 17);

ok(grep {
  $_->name() eq 'regulation of transmembrane transport'
} @loaded_cvterms);

my $hits =
  $ontology_index->lookup('biological_process', 'transmembrane transport', 100);

my @hits_list = ();

while (my $hit = $hits->next()) {
  push @hits_list, $hit;
}

is($hits_list[0]->{name}, 'transmembrane transport');
is($hits_list[1]->{name}, 'protein transmembrane transport');
