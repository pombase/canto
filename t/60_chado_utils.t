use strict;
use warnings;
use Test::More tests => 1;

use Canto::TestUtil;
use Canto::TrackDB;
use Canto::Chado::Utils;

use Test::Deep;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();
my $track_schema = Canto::TrackDB->new(config => $config);
my $chado_schema = $test_util->chado_schema();

my @stats_table = Canto::Chado::Utils::annotation_stats_table($chado_schema, $track_schema);

cmp_deeply(\@stats_table,
           [
             [
               2015,
               1,
               2
             ],
             [
               2016,
               1,
               0
             ]
           ]);
