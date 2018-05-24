use strict;
use warnings;
use Test::More tests => 1;
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
$load_util->get_strain($test_organism, 'strain 2');

my $strain_lookup = Canto::Track::StrainLookup->new(config => $test_util->config());

my @result_strains = $strain_lookup->lookup(4932);

cmp_deeply(\@result_strains, ['strain 1', 'strain 2']);

