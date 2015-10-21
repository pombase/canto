use strict;
use warnings;
use Test::More tests => 2;
use Test::Deep;
use Test::MockObject::Extends;

use Canto::TestUtil;
use Canto::Config::ExtensionSubsetProcess;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();

my $track_schema = Canto::TrackDB->new(config => $config);

my $index_path = $config->data_dir_path('ontology_index_dir');
my $ontology_index = Canto::Track::OntologyIndex->new(index_path => $index_path);

$test_util->load_test_ontologies($ontology_index, 1, 1);

my $test_go_obo_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_go_obo_file};

my $mock_request = Test::MockObject->new();
$mock_request->mock('param', sub { return 'track' });

my $processor = Canto::Config::ExtensionSubsetProcess->new(config => $config);

$processor = Test::MockObject::Extends->new($processor);
$processor->mock('get_owltools_results',
                 sub {
                   open my $fh, '<', $test_util->root_dir() . '/t/data/owltools_out.txt';
                   return $fh;
                 });

my $cvtermprop_rs = $track_schema->resultset('Cvtermprop');
my $cvtermprop_count = $cvtermprop_rs->count();

$processor->process($track_schema, $test_go_obo_file);

my $after_cvtermprop_count = $cvtermprop_rs->count();

is ($cvtermprop_count + 5, $after_cvtermprop_count);

my $prop_rs = $track_schema->resultset('Cvtermprop');

my @new_cvtermprops = ();

while (defined (my $prop = $prop_rs->next())) {
  if ($prop->type()->name() eq 'canto_subset') {
    push @new_cvtermprops,
      [$prop->cvterm()->name(), $prop->value()];
  };
}

@new_cvtermprops =
  sort {
   $a->[0] cmp $b->[1];
  } @new_cvtermprops;

cmp_deeply(\@new_cvtermprops,
           [
             [
               'cell phenotype',
               'FYPO:0000002'
             ],
             [
               'transport vesicle',
               'GO:0016023'
             ],
             [
               'stored secretory granule',
               'GO:0016023'
             ],
             [
               'cytoplasmic membrane-bounded vesicle',
               'GO:0016023'
             ],
             [
               'transmembrane transporter activity',
               'GO:0022857'
             ]
           ]);
