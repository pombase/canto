use strict;
use warnings;
use Test::More tests => 2;

use Plack::Test;
use Plack::Util;
use HTTP::Request::Common;

use Canto::TestUtil;
use Canto::Controller::Tools;

my $test_util = Canto::TestUtil->new();
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

  like ($res->content(), qr/has_substrate\(PomBase:SPBC1105.11c\)/);
};

done_testing;
