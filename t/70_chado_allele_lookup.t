use strict;
use warnings;
use Test::More tests => 1;
use Test::Deep;

use PomCur::Chado::AlleleLookup;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $lookup = PomCur::Chado::AlleleLookup->new(config => $test_util->config());

my $res = $lookup->lookup(search_string => 'ste');

cmp_deeply($res,
           [
           {
             name => 'ste20delta',
             description => 'del_x1',
             uniquename => 'SPBC12C2.02c:allele-1',
           }
         ]);
