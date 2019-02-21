use strict;
use warnings;
use Test::More tests => 7;
use Test::Deep;

use Canto::Track::OrganismLookup;
use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $lookup = Canto::Track::OrganismLookup->new(config => $test_util->config());

my @orgs = $lookup->lookup_by_type();

my $expected_org_4896 = {
  'pathogen_or_host' => 'unknown',
  'taxonid' => 4896,
  'scientific_name' => 'Schizosaccharomyces pombe',
  'full_name' => 'Schizosaccharomyces pombe',
  'common_name' => 'fission yeast',
};

cmp_deeply(\@orgs, [
  $expected_org_4896,
  {
    'scientific_name' => 'Saccharomyces cerevisiae',
    'taxonid' => 4932,
    'pathogen_or_host' => 'unknown',
    'full_name' => 'Saccharomyces cerevisiae',
    'common_name' => undef
  }
]);


# check for unknown taxon ID:
ok (!defined $lookup->lookup_by_taxonid(54321));


my $org_4896 = $lookup->lookup_by_taxonid(4896);
cmp_deeply($org_4896, $expected_org_4896);

# look up again to check caching code:
my $saved_schema = $lookup->{schema};
$lookup->{schema} = undef;
$org_4896 = $lookup->lookup_by_taxonid(4896);
cmp_deeply($org_4896, $expected_org_4896);

$lookup->{schema} = $saved_schema;


$test_util->config()->{host_organism_taxonids} = [4932];
$test_util->config()->_set_host_organisms($test_util->track_schema());


@orgs = $lookup->lookup_by_type('host');

my $expected_host_org_4932 = {
  'scientific_name' => 'Saccharomyces cerevisiae',
  'taxonid' => 4932,
  'pathogen_or_host' => 'host',
  'full_name' => 'Saccharomyces cerevisiae',
  'common_name' => undef
};

cmp_deeply(\@orgs, [
  $expected_host_org_4932,
]);

my $result_org_4932 = $lookup->lookup_by_taxonid(4932);
cmp_deeply($result_org_4932, $expected_host_org_4932);

my $result_org_undef = $lookup->lookup_by_taxonid(54321);
ok (!defined $result_org_undef);
