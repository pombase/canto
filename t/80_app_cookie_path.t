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

    my $test_base= "/tools";

    my $res = $test_util->app_login($cookie_jar, $cb, $test_base);

    like ($cookie_jar->as_string(), qr{PomCur_tools_session=[a-f0-9]+});
};

done_testing;
