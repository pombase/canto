use strict;
use warnings;
use Test::More tests => 2;

use PomCur::TestUtil;
use PomCur::Track::StatusStorage;
use PomCur::Track;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('1_curs');

my $track_schema = $test_util->track_schema();

my $curs_key = 'aaaa0001';

my $storage = PomCur::Track::StatusStorage->new(config => $test_util->config(),
                                                schema => $track_schema,
                                                curs_key => $curs_key);

$storage->store($curs_key, 'annotation_status', 'value1');
is($storage->retrieve($curs_key, 'annotation_status'), 'value1');

my @type_names = $storage->types();

ok(grep { $_ eq 'genes_annotated_count' } @type_names);
