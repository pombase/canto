use strict;
use warnings;
use Test::More tests => 2;

use Data::Compare;

use PomCur::TestUtil;
use PomCur::CursDB;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('1_curs');

my $config = $test_util->config();

my $schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0001');

ok($schema);

my $test_data = { year => 1999 };


# test inflating and deflating of data
$schema->txn_do(
  sub {
    $schema->create_with_type('Pub', { pubmedid => 12345678,
                                       title => "a title",
                                       abstract => "abstract text",
                                       data => $test_data });
  });

my $res_pub = $schema->find_with_type('Pub', { pubmedid => 12345678 });

my $res = $res_pub->data();

ok(Compare($res, $test_data));
