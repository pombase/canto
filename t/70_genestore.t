use strict;
use warnings;
use Test::More tests => 11;

use PomCur::Track::GeneStore;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $store = PomCur::Track::GeneStore->new(config => $test_util->config());

ok(defined $store->schema());

my $result = $store->lookup([qw(SPCC1739.10)]);

is(@{$result->{found}}, 1, 'look up one gene - found count');
is(@{$result->{missing}}, 0, 'look up one gene - missing count');

$result = $store->lookup([qw(missing1 missing2 missing3)]);
is(@{$result->{found}}, 0, 'look up with no results - found count');
is(@{$result->{missing}}, 3, 'look up with no results - missing count');

$result = $store->lookup([qw(SPCC1739.10 SPNCRNA.119 missing1 missing2 missing3)]);
is(@{$result->{found}}, 2, 'look up two genes by identifier - found count');
is(@{$result->{missing}}, 3, 'look up two genes by identifier - missing count');

$result = $store->lookup([qw(wtf22 cdc11 missing1 missing2 missing3)]);
is(@{$result->{found}}, 2, 'look up two genes by name - found count');
is(@{$result->{missing}}, 3, 'look up two genes by name - missing count');

$result = $store->lookup([qw(SPCC1739.10 wtf22 cdc11 missing1 missing2 missing3)]);
is(@{$result->{found}}, 3, 'look up two genes by name and identifier - found count');
is(@{$result->{missing}}, 3, 'look up two genes by name and identifier - missing count');

