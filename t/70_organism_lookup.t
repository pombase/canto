use strict;
use warnings;
use Test::More tests => 6;
use Test::Deep;

use Canto::Track::OrganismLookup;
use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $lookup = Canto::Track::OrganismLookup->new(config => $test_util->config());

my @orgs = $lookup->lookup_by_type('host');

my $expected_org_4896 = {
  'pathogen_or_host' => 'unknown',
  'taxon_id' => 4896,
  'species' => 'pombe',
  'genus' => 'Schizosaccharomyces'
};

cmp_deeply(\@orgs, [
  $expected_org_4896,
  {
    'species' => 'cerevisiae',
    'taxon_id' => 4932,
    'pathogen_or_host' => 'unknown',
    'genus' => 'Saccharomyces'
  }
]);


my $org_4896 = $lookup->lookup_by_taxonid(4896);

cmp_deeply($org_4896, $expected_org_4896);


$test_util->config()->{host_organism_taxonids} = [4932];
$test_util->config()->_set_host_organisms($test_util->track_schema());


@orgs = $lookup->lookup_by_type('host');

my $expected_path_org_4896 = {
  'pathogen_or_host' => 'pathogen',
  'taxon_id' => 4896,
  'species' => 'pombe',
  'genus' => 'Schizosaccharomyces'
};

my $expected_host_org_4932 = {
  'species' => 'cerevisiae',
  'taxon_id' => 4932,
  'pathogen_or_host' => 'host',
  'genus' => 'Saccharomyces'
};

cmp_deeply(\@orgs, [
  $expected_path_org_4896,
  $expected_host_org_4932,
]);

my $result_org_4896 = $lookup->lookup_by_taxonid(4896);
cmp_deeply($result_org_4896, $expected_path_org_4896);

my $result_org_4932 = $lookup->lookup_by_taxonid(4932);
cmp_deeply($result_org_4932, $expected_host_org_4932);

my $result_org_undef = $lookup->lookup_by_taxonid(54321);
ok (!defined $result_org_undef);
