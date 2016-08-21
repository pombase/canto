use strict;
use warnings;
use Test::More tests => 21;
use Test::Deep;

use Canto::TestUtil;
use Canto::Track::OntologyIndex;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('empty_db', { copy_ontology_index => 0 });

my $config = $test_util->config();
my $schema = Canto::TrackDB->new(config => $config);

my $test_go_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_go_obo_file};

my $synonym_types = $config->{load}->{ontology}->{synonym_types};
my $index_path = $config->data_dir_path('ontology_index_dir');

my $dihydropteroate_name = 'dihydropteroate synthase activity';

sub _make_index
{
  my $ontology_index = Canto::Track::OntologyIndex->new(config => $config, index_path => $index_path);
  $ontology_index->initialise_index();

  my @data = (
    ['molecular_function', 'molecular_function', 120000, 'GO:0003674', ['GO:0003674', 'canto_root_subset'], []],
    ['molecular_function', $dihydropteroate_name, 123000, 'GO:0004156', ['GO:0003674'], []],
    ['molecular_function', 'transporter activity', 123001, 'GO:0005215', ['GO:0003674'],
     [
       {
         synonym => "small-molecule carrier or transporter",
         type => 'exact'
       },
     ]
   ],
    ['molecular_function', 'transmembrane transporter activity', 123002, 'GO:0022857', ['GO:0003674', 'GO:0005215'], []],
    ['molecular_function', 'nucleocytoplasmic transporter activity', 123003, 'GO:0005215', ['GO:0003674', 'GO:0005215'], []],
    ['biological_process', 'transport', 123004, 'GO:0006810', ['GO:0006810'], []],
    ['biological_process', 'transmembrane transport', 123005, 'GO:0055085', ['GO:0006810', 'GO:0055085'], []],
    ['biological_process', 'transporter activity', 123006, 'GO:0005215', ['GO:0055085'], []],
  );

  map {
    $ontology_index->add_to_index(@$_);
  } @data;

  $ontology_index->finish_index();

  return $ontology_index;
}

my $ontology_index = _make_index();

my @results = $ontology_index->lookup('molecular_function', [], 'dihydropteroate', 100);
is(@results, 1);

is($results[0]->{term_name}, $dihydropteroate_name);

@results = $ontology_index->lookup('molecular_function', [], 'molecular_function', 100);
is(@results, 1);

@results = $ontology_index->lookup('molecular_function', [], 'small molecule', 100);
is(@results, 1);

@results = $ontology_index->lookup('molecular_function', [], 'transporter activity', 100);
is(@results, 4);

cmp_deeply(
    [
      map {
        $_->{term_name}
      } @results
    ], ['transporter activity',
        'transmembrane transporter activity',
        'nucleocytoplasmic transporter activity',
        'dihydropteroate synthase activity']);

@results = $ontology_index->lookup('molecular_function', ['canto_root_subset'], 'molecular_function', 100);
is(@results, 0);

@results = $ontology_index->lookup('molecular_function', [], 'activity', 100);
is(@results, 4);

@results = $ontology_index->lookup('molecular_function', ['canto_root_subset'], 'activity', 100);
is(@results, 4);

@results = $ontology_index->lookup('molecular_function', [], 'act', 100);
is(@results, 4);

@results = $ontology_index->lookup(['GO:0003674'], [], 'activity', 100);
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
@results = $ontology_index->lookup(['GO:0005215'], [], 'activity', 100);
is(@results, 2);
check_subset_results(@results);

@results = $ontology_index->lookup(['GO:0003674','GO:1234567'], [], 'activity', 100);
is(@results, 4);

@results = $ontology_index->lookup('biological_process', [], 'transport*', 100);
is(@results, 3);

@results = $ontology_index->lookup(['GO:0006810'], [], 'transport', 100);
is(@results, 2);

@results = $ontology_index->lookup([{include => 'GO:0006810', exclude => 'GO:0055085'}], [],
                                   'transport', 100);
is(@results, 1);

@results = $ontology_index->lookup(['GO:0003674'], [], 'molecular_function', 100);
is(@results, 1);

@results = $ontology_index->lookup(['GO:0003674'], ['canto_root_subset'], 'molecular_function', 100);
is(@results, 0);


undef $ontology_index;


# new index to test term_boosts

$config->{load}->{ontology}->{term_boosts}->{'GO:0022857'} = 10.0;

$ontology_index = _make_index();

@results = $ontology_index->lookup('molecular_function', [], 'transporter activity', 100);
is(@results, 4);

cmp_deeply(
    [
      map {
        $_->{term_name}
      } @results
    ], ['transmembrane transporter activity',
        'transporter activity',
        'nucleocytoplasmic transporter activity',
        'dihydropteroate synthase activity']);

