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

test_psgi $app, sub {
    my $cb = shift;

    my $test_base= "/tools";

    my $res = $test_util->app_login($cookie_jar, $cb, $test_base);

    my $app_name = $config->{name};
    like ($cookie_jar->as_string(), qr{${app_name}_tools_session=[a-f0-9]+});
};

done_testing;
