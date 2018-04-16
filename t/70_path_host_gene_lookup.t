use strict;
use warnings;
use Test::More tests => 1;

use Try::Tiny;
use Canto::Track::GeneLookup;
use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();
$test_util->init_test();
my $track_schema = $test_util->track_schema();

my $lookup = Canto::Track::GeneLookup->new(config => $test_util->config());

$test_util->config()->{host_organism_taxonids} = [4896];
$test_util->config()->_set_host_organisms($track_schema);

my $result = $lookup->lookup(
  [qw(klp1)]);

is(@{$result->{found}}, 1);
