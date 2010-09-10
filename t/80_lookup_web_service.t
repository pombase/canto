use strict;
use warnings;
use Test::More tests => 1;

use PomCur::TestUtil;

use PomCur::Track;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $config = $test_util->config();
my $lookup = PomCur::Track::get_lookup($config, 'go');


package MockRequest;

sub param
{
  return 'GO:000';
}


package MockCatalyst;

sub req
{
  return bless {}, 'MockRequest';
}


package main;

my $c = bless {}, 'MockCatalyst';

my $results = $lookup->web_service_lookup($c, 'component', 'term', 10);

ok(defined $results);

