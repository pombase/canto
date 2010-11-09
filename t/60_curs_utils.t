use strict;
use warnings;
use Test::More tests => 4;

use PomCur::TestUtil;
use PomCur::Curs::Utils;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('curs_annotations_1');

my $config = $test_util->config();
my $schema = $test_util->track_schema();

my $curs_schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0005');

my @annotations =
  PomCur::Curs::Utils::get_annotation_table($config, $curs_schema);

is (@annotations, 1);

is ($annotations[0]->{gene_identifier}, 'SPCC1739.10');
is ($annotations[0]->{term_ontid}, 'GO:0055085');
like ($annotations[0]->{creation_date}, qr/\d+-\d+-\d+/);
