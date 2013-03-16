use strict;
use warnings;
use Test::More tests => 2;
use Test::Deep;

use PomCur::Chado::AlleleLookup;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $lookup = PomCur::Chado::AlleleLookup->new(config => $test_util->config());

my $res = $lookup->lookup(gene_primary_identifier => 'SPBC12C2.02c',
                          search_string => 'ste');

cmp_deeply($res,
           [
           {
             name => 'ste20delta',
             description => 'del_x1',
             allele_type => 'deletion',
             uniquename => 'SPBC12C2.02c:allele-1',
             display_name => 'ste20delta(del_x1)',
           }
         ]);

# search with gene constrained to a another gene
$res = $lookup->lookup(gene_primary_identifier => 'SPCC16A11.14',
                          search_string => 'ste');

cmp_deeply($res, []);
