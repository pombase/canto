use strict;
use warnings;
use Test::More;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $app = $test_util->plack_app();

test_psgi $app, sub {
  my $cb = shift;

  # test viewing an object
  {
    my $url = 'http://localhost:5000/view/object/person/1?model=track';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    ok ($res->content() =~ /Details for Val Wood/);
    ok ($res->content() =~ /Val Wood/);
  }

  # test viewing a list
  {
    my $url = 'http://localhost:5000/view/list/lab?model=track';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;
    ok ($res->content() =~ /List of all labs/);
    ok ($res->content() =~ /Nick Rhind/);
    ok ($res->content() =~ /12\b.* rows found/);
  }
};

done_testing;
