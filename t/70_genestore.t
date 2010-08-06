use strict;
use warnings;
use Test::More tests => 1;

use PomCur::Track::GeneStore;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $store = PomCur::Track::GeneStore->new(config => $test_util->config());

ok(defined $store->schema());

my @results = $store->lookup([qw(SPCC1739.10)]);

is(@results, 1, 'look up one gene');

@results = $store->lookup([qw(SPCC1739.10 SPNCRNA.119)]);
is(@results, 2, 'look up two genes');

