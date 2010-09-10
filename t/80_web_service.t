use strict;
use warnings;
use Test::More;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

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

my $app = $test_util->plack_app();

test_psgi $app, sub {
  my $cb = shift;

  {
    my $search_term = 'GO:0050';
    my $url = "http://localhost:5000/ws/lookup/go/component/term/10/?term=$search_term";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    use JSON::Any;

    my $json_any = JSON::Any->new();
    my $obj = $json_any->jsonToObj($res->content());

    ok(grep { $_->{match} =~ /$search_term/ } @$obj);
  }
};

done_testing;
