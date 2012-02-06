use strict;
use warnings;
use Test::More tests => 13;

use Plack::Test;
use Plack::Util;
use HTTP::Request::Common;
use HTTP::Cookies;

use PomCur::TestUtil;
use PomCur::Controller::Tools;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();

my $app = $test_util->plack_app()->{app};

test_psgi $app, sub {
  my $cb = shift;

  my $url = 'http://localhost:5000/tools/ann_ex_locations';
  my $req = HTTP::Request->new(GET => $url);
  my $res = $cb->($req);

  is $res->code, 200;

die $res->content();

  like ($res->content(), qr/Details for Val Wood/);
};

done_testing;
