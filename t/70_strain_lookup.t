use strict;
use warnings;
use Test::More tests => 6;
use Test::Deep;

use Canto::Track::StrainLookup;
use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $schema = $test_util->track_schema();
my $load_util = Canto::Track::LoadUtil->new(schema => $schema);

my $test_organism = $load_util->find_organism_by_taxonid(4932);

if (!$test_organism) {
  fail qq(No organism with taxon ID 4932);
}

$load_util->get_strain($test_organism, 'strain 1');
my $strain_2 = $load_util->get_strain($test_organism, 'strain 2');

for my $i (1..2) {
  $schema->create_with_type('Strainsynonym', {
    strain => $strain_2,
    synonym => 'str2-syn-' . $i,
  });
}

my $strain_lookup = Canto::Track::StrainLookup->new(config => $test_util->config());

my @result_strains = $strain_lookup->lookup(4932);

my $strain_1_expected = {
  strain_id => 1, strain_name => 'strain 1',
  synonyms => [], taxon_id => 4932,
};
my $strain_2_expected = {
 strain_id => 2, strain_name => 'strain 2',
 synonyms => ['str2-syn-1', 'str2-syn-2'],
 taxon_id => 4932,
};

cmp_deeply(\@result_strains, [$strain_1_expected, $strain_2_expected]);


my @strain_by_id_result = $strain_lookup->lookup_by_strain_ids(2);
cmp_deeply(\@strain_by_id_result, [$strain_2_expected]);

@strain_by_id_result = $strain_lookup->lookup_by_strain_ids(2, 1);
cmp_deeply(\@strain_by_id_result, [$strain_1_expected, $strain_2_expected]);

my @unknown_by_id_result = $strain_lookup->lookup_by_strain_ids(876543);
ok(@unknown_by_id_result == 0);

my $strain_by_name_result = $strain_lookup->lookup_by_strain_name(4932, 'strain 2');
cmp_deeply($strain_by_name_result, $strain_2_expected);

my $unknown_by_name = $strain_lookup->lookup_by_strain_name("UNKNOWN_STRAIN_NAME_");
ok(!defined $unknown_by_name);
