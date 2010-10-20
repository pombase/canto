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

my $app = $test_util->plack_app();

test_psgi $app, sub {
  my $cb = shift;

  {
    my $search_term = 'transport';
    my $url = "http://localhost:5000/ws/lookup/go/component/?term=$search_term";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    use JSON::Any;

    my $json_any = JSON::Any->new();
    my $obj = $json_any->jsonToObj($res->content());

    is (@$obj, 2);

    ok(grep { $_->{id} =~ /GO:0005215/ } @$obj);
    ok(grep { $_->{name} =~ /transporter activity/ } @$obj);
  }
};

done_testing;
