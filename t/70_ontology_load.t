use strict;
use warnings;
use Test::More tests => 3;

use Data::Compare;

use PomCur::TestUtil;
use PomCur::Track::OntologyLoad;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('empty_db');

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @loaded_cvterms = $schema->resultset('Cvterm')->all();

is (@loaded_cvterms, 0);

my $test_ontology_file = $test_util->root_dir() . '/t/data/small.obo';

my $ontology_load = PomCur::Track::OntologyLoad->new(schema => $schema);
$ontology_load->load($test_ontology_file);

@loaded_cvterms = $schema->resultset('Cvterm')->all();

is(@loaded_cvterms, 16);

ok(grep {
  $_->name() eq 'regulation of transmembrane transport'
} @loaded_cvterms);
