use strict;
use warnings;
use Test::More tests => 1;

use Test::Deep;

use Canto::Chado::GenotypeLookup;

use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $lookup = Canto::Chado::GenotypeLookup->new(config => $test_util->config());

my $res = $lookup->lookup(gene_primary_identifiers => ['SPBC12C2.02c']);

use Data::Dumper;
$Data::Dumper::Maxdepth = 3;
die Dumper([$res]);


