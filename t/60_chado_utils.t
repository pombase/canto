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

my %curation_stats = Canto::Chado::Utils::curation_stats($chado_schema, $track_schema);

cmp_deeply(\%curation_stats,
           {
             'annual_community_annotation_counts' => {
               '2015' => 2
             },
             'annual_curator_annotation_counts' => {
               '2016' => 1,
               '2015' => 1
             }
           });
