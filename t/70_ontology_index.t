use strict;
use warnings;
use Test::More tests => 11;
use Test::Deep;

use Canto::TestUtil;
use Canto::Track::OntologyIndex;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('empty_db', { copy_ontology_index => 0 });

my $config = $test_util->config();
my $schema = Canto::TrackDB->new(config => $config);

my @loaded_cvterms = $schema->resultset('Cvterm')->all();

is (@loaded_cvterms, 123);

my $test_go_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_go_obo_file};

my $synonym_types = $config->{load}->{ontology}->{synonym_types};
my $index_path = $config->data_dir_path('ontology_index_dir');

my $ontology_index = Canto::Track::OntologyIndex->new(index_path => $index_path);
$ontology_index->initialise_index();

my $dihydropteroate_name = 'dihydropteroate synthase activity';

my @data = (
  ['molecular_function', 'molecular_function', 120000, 'GO:0003674', ['GO:0003674'], []],
  ['molecular_function', $dihydropteroate_name, 123000, 'GO:0004156', ['GO:0003674'], []],
  ['molecular_function', 'transporter activity', 123001, 'GO:0005215', ['GO:0003674'], []],
  ['molecular_function', 'transmembrane transporter activity', 123002, 'GO:0022857', ['GO:0003674', 'GO:0005215'], []],
  ['molecular_function', 'nucleocytoplasmic transporter activity', 123003, 'GO:0005215', ['GO:0003674', 'GO:0005215'], []],
  );

map {
  $ontology_index->add_to_index(@$_);
} @data;

$ontology_index->finish_index();

my @results = $ontology_index->lookup('molecular_function', 'dihydropteroate', 100);
is(@results, 1);

is($results[0]->{term_name}, $dihydropteroate_name);

@results = $ontology_index->lookup('molecular_function', 'molecular_function', 100);
is(@results, 1);

@results = $ontology_index->lookup('molecular_function', 'activity', 100);
is(@results, 4);

@results = $ontology_index->lookup('molecular_function', 'act', 100);
is(@results, 4);

@results = $ontology_index->lookup(['GO:0003674'], 'activity', 100);
is(@results, 4);

sub check_subset_results
{
  my @results = @_;
  cmp_deeply(
    [
      sort map {
        $_->{term_name}
      } @results
    ],
    ['nucleocytoplasmic transporter activity',
     'transmembrane transporter activity']);
}

# a subset:
@results = $ontology_index->lookup(['GO:0005215'], 'activity', 100);
is(@results, 2);
check_subset_results(@results);

@results = $ontology_index->lookup(['GO:0003674','GO:1234567'], 'activity', 100);
is(@results, 4);

@results = $ontology_index->lookup(['GO:0003674'], 'molecular_function', 100);
is(@results, 1);


undef $ontology_index;
