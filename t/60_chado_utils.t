use strict;
use warnings;
use Test::More tests => 1;

use Canto::TestUtil;
use Canto::TrackDB;
use Canto::Chado::Utils;

use Test::Deep;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = Canto::TrackDB->new(config => $config);
my $chado_schema = $test_util->chado_schema();

my $annotation_status_term =
  $track_schema->resultset('Cvterm')->find({ name => 'annotation_status' });
my $annotation_status_datestamp_term =
  $track_schema->resultset('Cvterm')->find({ name => 'annotation_status_datestamp' });
my $curs_obj =
  $track_schema->resultset('Curs')->find({ curs_key => 'aaaa0007' });

$track_schema->resultset('Cursprop')
  ->search({ type => $annotation_status_term->cvterm_id(),
             curs => $curs_obj->curs_id()  })
  ->update({ value => 'APPROVED' });
$track_schema->resultset('Cursprop')
  ->search({ type => $annotation_status_datestamp_term->cvterm_id(),
             curs => $curs_obj->curs_id() })
  ->update({ value => '2013-12-02 16:21:56' });

my @stats_table = Canto::Chado::Utils::annotation_stats_table($chado_schema, $track_schema);

cmp_deeply(\@stats_table,
           [
             [2015, 0, 0, 2, 2],
             [2016, 0, 0, 0, 0]
           ]);
