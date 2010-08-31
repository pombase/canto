use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;

use PomCur::TestUtil;

{
  my $test_util = PomCur::TestUtil->new();

  ok(ref $test_util);

  throws_ok { $test_util->init_test('_no_such_config_') } qr(no test case);

}

{
  my $test_util = PomCur::TestUtil->new();

  ok(ref $test_util);

  $test_util->init_test('empty_db');

  is($test_util->track_schema()->resultset('Pub')->count(), 0);
  is($test_util->track_schema()->resultset('Gene')->count(), 0);
}

{
  my $test_util = PomCur::TestUtil->new();

  ok(ref $test_util);

  $test_util->init_test('1_curs');

  is($test_util->track_schema()->resultset('Pub')->count(), 16);
  is($test_util->track_schema()->resultset('Gene')->count(), 7);
}
