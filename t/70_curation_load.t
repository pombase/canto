use strict;
use warnings;
use Test::More tests => 2;

use Data::Compare;

use PomCur::TestUtil;
use PomCur::Track::CurationLoad;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('empty_db');

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @loaded_pubs = $schema->resultset('Pub')->all();

is (@loaded_pubs, 0);

my $test_curation_file =
  $test_util->root_dir() . '/t/data/community_curation_stats_small.txt';

my $curation_load = PomCur::Track::CurationLoad->new(schema => $schema);
$curation_load->load($test_curation_file);

@loaded_pubs = $schema->resultset('Pub')->all();

is(@loaded_pubs, 17);
