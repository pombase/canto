use strict;
use warnings;
use Test::More tests => 1;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

ok(ref $test_util);
