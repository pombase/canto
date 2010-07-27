use strict;
use warnings;
use Test::More;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} = 'test';

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $psgi_script_name = $test_util->root_dir() . '/script/pomcur_psgi.pl';
my $app = Plack::Util::load_psgi($psgi_script_name);

test_psgi $app, sub {
    my $cb = shift;

    my $url = 'http://localhost:5000/view/object/person/1?model=manage';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;
    ok ($res->content() =~ /Details for/);
    ok ($res->content() =~ /Val Wood/);
};

done_testing;
