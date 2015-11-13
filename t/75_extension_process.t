use strict;
use warnings;
use Test::More tests => 6;
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

my $prop_rs = $track_schema->resultset('Cvtermprop');
my $cvtermprop_count = $prop_rs->count();
my $subset_prop_rs = $prop_rs
  ->search({ 'type.name' => 'canto_subset' },
           { join => 'type', prefetch => 'cvterm' });

is ($subset_prop_rs->count(), 0);

my $closure_data = $processor->get_closure_data($test_go_obo_file);
$processor->process_closure($track_schema, $closure_data);

my $after_cvtermprop_count = $prop_rs->count();

is ($cvtermprop_count + 10, $after_cvtermprop_count);


sub get_subset_props
{
  return
    sort {
      $a->[0] cmp $b->[0]
        ||
      $a->[1] cmp $b->[1];
    } map {
      [$_->cvterm()->name(), $_->value()];
    } $subset_prop_rs->all();
}

my @subset_cvtermprops = get_subset_props();

cmp_deeply(\@subset_cvtermprops,
           [
             [
               'cell phenotype',
               'FYPO:0000002'
             ],
             [
               'cellular_component',
               'GO:0005575'
             ],
             [
               'cytoplasmic membrane-bounded vesicle',
               'GO:0005575'
             ],
             [
               'cytoplasmic membrane-bounded vesicle',
               'GO:0016023'
             ],
             [
               'regional_centromere_outer_repeat_region',
               'SO:0001799'
             ],
             [
               'stored secretory granule',
               'GO:0005575'
             ],
             [
               'stored secretory granule',
               'GO:0016023'
             ],
             [
               'transmembrane transporter activity',
               'GO:0022857'
             ],
             [
               'transport vesicle',
               'GO:0005575'
             ],
             [
               'transport vesicle',
               'GO:0016023'
             ]
           ]);

is ($subset_prop_rs->count(), 10);

# run again to make sure it's repeatable
$processor->process_closure($track_schema, $closure_data);

is ($prop_rs->count(), $cvtermprop_count + scalar(@subset_cvtermprops));
is ($subset_prop_rs->count(), 10);
