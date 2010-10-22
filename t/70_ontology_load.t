use strict;
use warnings;
use Test::More tests => 3;

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

my $test_ontology_file = $test_util->root_dir() . '/t/data/go_small.obo';

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

while (my $hit = $hits->fetch_hit_hashref) {
  my $score = sprintf( "%0.3f", $hit->{score} );
  my $name = $hit->{name};
  my $ontid = $hit->{ontid};
  my $cvterm_id = $hit->{ontid};

  warn "$score $ontid $name\n";
}
