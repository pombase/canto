use strict;
use warnings;
use Test::More;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $app = $test_util->plack_app()->{app};

my $cookie_jar = $test_util->cookie_jar();

test_psgi $app, sub {
    my $cb = shift;

    my $req = HTTP::Request->new(GET => 'http://localhost:5000/');

    my $res = $cb->($req);

    is $res->code, 200;
    ok ($res->content() =~ /Start page/);

    ok ($res->content() !~ /Reports/);

    $test_util->app_login($cookie_jar, $cb);
    $cookie_jar->add_cookie_header($req);

    $res = $cb->($req);
    ok ($res->content() =~ /Reports/);
};

done_testing;
