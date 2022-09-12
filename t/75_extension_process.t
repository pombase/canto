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

is ($subset_prop_rs->count(), 14);


my $canto_root_subset_count = $subset_prop_rs->count();

my $subset_data = $extension_process->get_subset_data($test_go_obo_file);
my $subset_process = Canto::Chado::SubsetProcess->new();

$subset_process->add_to_subset($subset_data, 'canto_root_subset', 'is_a',
                               ['GO:0003674', 'GO:0005575', 'GO:0008150']);
is ($subset_data->{'GO:0005575'}{canto_root_subset}{is_a}, 1);

$subset_process->process_subset_data($track_schema, $subset_data);

my $after_cvtermprop_count = $prop_rs->count();

is ($after_cvtermprop_count, 56);

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
      'abnormal cell morphology',
      'is_a(FYPO:0000005)'
    ],
    [
      'biological_process',
      'is_a(canto_root_subset)'
    ],
    [
      'cell phenotype',
      'is_a(FYPO:0000002)'
    ],
    [
      'cellular_component',
      'is_a(canto_root_subset)'
    ],
    [
      'cytoplasmic membrane-bounded vesicle',
      'is_a(GO:0016023)'
    ],
    [
      'disease formation phenotype',
      'is_a(canto_root_subset)'
    ],
    [
      'disease formation phenotype',
      'is_a(qc_do_not_annotate)'
    ],
   [
      'fission yeast phenotype condition',
      'is_a(canto_root_subset)'
    ],
     [
      'glucose rich medium',
      'is_a(Grouping_terms)'
    ],
    [
      'growth medium',
      'is_a(Grouping_terms)'
    ],
    [
      'hydrogen peroxide transmembrane transport',
      'is_a(GO:0006810)'
    ],
    [
      'hydrogen peroxide transmembrane transport',
      'is_a(GO:0055085)'
    ],
    [
      'medium components',
      'is_a(Grouping_terms)'
    ],
    [
      'molecular_function',
      'is_a(canto_root_subset)'
    ],
    [
      'negative regulation of transmembrane transport',
      'is_a(GO:0034762)'
    ],
    [
      'nucleocytoplasmic transporter activity',
      'is_a(GO:0005215)'
    ],
    [
      'positive regulation of transmembrane transport',
      'is_a(GO:0034762)'
    ],
    [
      'protein modification',
      'is_a(canto_root_subset)'
    ],
    [
      'protein transmembrane transport',
      'is_a(GO:0006810)'
    ],
    [
      'protein transmembrane transport',
      'is_a(GO:0055085)'
    ],
    [
      'regional_centromere_outer_repeat_region',
      'is_a(SO:0001799)'
    ],
    [
      'regulation of transmembrane transport',
      'is_a(GO:0034762)'
    ],
    [
      'rich medium',
      'is_a(Grouping_terms)'
    ],
    [
      'stored secretory granule',
      'is_a(GO:0016023)'
    ],
    [
      'transmembrane transport',
      'is_a(GO:0006810)'
    ],
    [
      'transmembrane transport',
      'is_a(GO:0055085)'
    ],
    [
      'transmembrane transporter activity',
      'is_a(GO:0005215)'
    ],
    [
      'transmembrane transporter activity',
      'is_a(GO:0022857)'
    ],
    [
      'transport',
      'is_a(GO:0006810)'
    ],
    [
      'transport vesicle',
      'is_a(GO:0016023)'
    ],
    [
      'transporter activity',
      'is_a(GO:0005215)'
    ]
);

cmp_deeply(\@subset_cvtermprops, \@expected_subset_props);

# run again to make sure it's repeatable
$subset_process->process_subset_data($track_schema, $subset_data);

is ($prop_rs->count() + $canto_root_subset_count,
    $cvtermprop_count + scalar(@subset_cvtermprops));
is ($subset_prop_rs->count(), scalar(@expected_subset_props));
