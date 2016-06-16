use strict;
use warnings;
use Test::More tests => 6;
use Test::Deep;
use Test::MockObject::Extends;

use Canto::TestUtil;
use Canto::Config::ExtensionProcess;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();

my $track_schema = Canto::TrackDB->new(config => $config);

my $index_path = $config->data_dir_path('ontology_index_dir');
my $ontology_index = Canto::Track::OntologyIndex->new(config => $config, index_path => $index_path);

$test_util->load_test_ontologies($ontology_index, 1, 1);

my $test_go_obo_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_go_obo_file};


my $extension_process = $test_util->get_mock_extension_process();

my $prop_rs = $track_schema->resultset('Cvtermprop');
my $cvtermprop_count = $prop_rs->count();
my $subset_prop_rs = $prop_rs
  ->search({ 'type.name' => 'canto_subset' },
           { join => 'type', prefetch => 'cvterm', order_by => [ 'type.name', 'value' ] });

is ($subset_prop_rs->count(), 12);


my $canto_root_subset_count = $subset_prop_rs->count();

my $subset_data = $extension_process->get_subset_data($test_go_obo_file);
my $subset_process = Canto::Chado::SubsetProcess->new();

$subset_process->add_to_subset($subset_data, 'canto_root_subset',
                               ['GO:0003674', 'GO:0005575', 'GO:0008150']);
is ($subset_data->{'GO:0005575'}{canto_root_subset}, 1);

$subset_process->process_subset_data($track_schema, $subset_data);

my $after_cvtermprop_count = $prop_rs->count();

is ($after_cvtermprop_count, 51);


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

my @expected_subset_props =
  (
    [
      'biological_process',
      'canto_root_subset'
    ],
    [
      'cell phenotype',
      'FYPO:0000002'
    ],
    [
      'cellular_component',
      'canto_root_subset'
    ],
    [
      'cytoplasmic membrane-bounded vesicle',
      'GO:0016023'
    ],
    [
      'hydrogen peroxide transmembrane transport',
      'GO:0006810'
    ],
    [
      'hydrogen peroxide transmembrane transport',
      'GO:0055085'
    ],
    [
      'molecular_function',
      'canto_root_subset'
    ],
    [
      'negative regulation of transmembrane transport',
      'GO:0034762'
    ],
    [
      'negative regulation of transmembrane transport',
      'GO:0055085'
    ],
    [
      'nucleocytoplasmic transporter activity',
      'GO:0005215'
    ],
    [
      'phenotype condition',
      'canto_root_subset'
    ],
    [
      'positive regulation of transmembrane transport',
      'GO:0034762'
    ],
    [
      'positive regulation of transmembrane transport',
      'GO:0055085'
    ],
    [
      'protein modification',
      'canto_root_subset'
    ],
    [
      'protein transmembrane transport',
      'GO:0006810'
    ],
    [
      'protein transmembrane transport',
      'GO:0055085'
    ],
    [
      'regional_centromere_outer_repeat_region',
      'SO:0001799'
    ],
    [
      'regulation of transmembrane transport',
      'GO:0034762'
    ],
    [
      'regulation of transmembrane transport',
      'GO:0055085'
    ],
    [
      'stored secretory granule',
      'GO:0016023'
    ],
    [
      'transmembrane transport',
      'GO:0006810'
    ],
    [
      'transmembrane transport',
      'GO:0055085'
    ],
    [
      'transmembrane transporter activity',
      'GO:0005215'
    ],
    [
      'transmembrane transporter activity',
      'GO:0022857'
    ],
    [
      'transmembrane transporter activity',
      'GO:0055085'
    ],
    [
      'transport',
      'GO:0006810'
    ],
    [
      'transport vesicle',
      'GO:0016023'
    ],
    [
      'transporter activity',
      'GO:0005215'
    ]
  );

cmp_deeply(\@subset_cvtermprops, \@expected_subset_props);

# run again to make sure it's repeatable
$subset_process->process_subset_data($track_schema, $subset_data);

is ($prop_rs->count() + $canto_root_subset_count,
    $cvtermprop_count + scalar(@subset_cvtermprops));
is ($subset_prop_rs->count(), scalar(@expected_subset_props));
