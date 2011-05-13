use strict;
use warnings;
use Test::More tests => 2;

use PomCur::TestUtil;
use PomCur::TrackDB;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @results = $schema->resultset('Organism')->search();

is(@results, 2);

my $organism = $results[0];

is($organism->taxonid(), 4896);
