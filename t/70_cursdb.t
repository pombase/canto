use strict;
use warnings;
use Test::More tests => 3;

use Data::Compare;

use PomCur::TestUtil;
use PomCur::CursDB;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('curs_annotations_1');

my $config = $test_util->config();

my $schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0005');

ok($schema);

# test inflating and deflating of data
$schema->txn_do(
  sub {
    $schema->create_with_type('Pub', { uniquename => 12345678,
                                       title => "a title",
                                       abstract => "abstract text",
                                     });
  });

my $res_pub = $schema->find_with_type('Pub', { uniquename => 12345678 });

$res_pub->update();

my $new_res_pub = $schema->find_with_type('Pub', { uniquename => 12345678 });

my $cdc11 = $schema->find_with_type('Gene', { primary_name => 'cdc11' });
my @cdc11_annotations = $cdc11->annotations();
is (@cdc11_annotations, 0);

my $g1739_10 = $schema->find_with_type('Gene',
                                       { primary_identifier => 'SPCC1739.10' });
my @g1739_10_annotations = $g1739_10->annotations();
is (@g1739_10_annotations, 1);
