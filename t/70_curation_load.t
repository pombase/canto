use strict;
use warnings;
use Test::More tests => 2;

use Canto::TestUtil;
use Canto::Track::CurationLoad;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('empty_db');

my $config = $test_util->config();
my $schema = Canto::TrackDB->new(config => $config);

my @loaded_pubs = $schema->resultset('Pub')->all();

is (@loaded_pubs, 0);

my $test_curation_file =
  $test_util->root_dir() . '/t/data/community_curation_stats_small.txt';

my $curation_load = Canto::Track::CurationLoad->new(schema => $schema);
$curation_load->load($test_curation_file);

@loaded_pubs = $schema->resultset('Pub')->all();

is(@loaded_pubs, 17);
