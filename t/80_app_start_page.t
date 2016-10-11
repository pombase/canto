use strict;
use warnings;
use Test::More;

use Canto::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

my $test_util = Canto::TestUtil->new();
$test_util->init_test();

my $config = $test_util->config();
my $app = $test_util->plack_app()->{app};

my $cookie_jar = $test_util->cookie_jar();

$test_util->enable_access_control();

test_psgi $app, sub {
    my $cb = shift;

    my $req = HTTP::Request->new(GET => 'http://localhost:5000/track/');

    my $res = $cb->($req);

    is $res->code, 200;

    ok ($res->content() =~ /Log in to continue/);
    ok ($res->content() !~ /Reports/);

    $test_util->app_login($cookie_jar, $cb);
    $cookie_jar->add_cookie_header($req);

    $res = $cb->($req);
    ok ($res->content() =~ /Reports/);
    my $app_name = $config->{name};
};

done_testing;
