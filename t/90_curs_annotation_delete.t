use strict;
use warnings;
use Test::More tests => 5;

use Data::Compare;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

use PomCur::TestUtil;
use PomCur::Controller::Curs;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('curs_annotations_1');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();

my $app = $test_util->plack_app()->{app};

my $curs_schema = PomCur::Curs::get_schema_for_key($config, $curs_key);

my $root_url = "http://localhost:5000/curs/$curs_key";

my $delete_annotation_re =
  qr/SPAC3A11.14c.*GO:0030133.*IPI.*SPCC1739.10/s;
my $other_annotation_re =
  qr/SPCC1739.10.*GO:0055085.*IMP/s;

test_psgi $app, sub {
  my $cb = shift;

  my $term_id = 'GO:0080170';

  sub check_not_deleted {
    my $cb = shift;
    my $uri = new URI("$root_url");
    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    # make sure we actually change the list of annotations later
    like ($res->content(), qr/$delete_annotation_re.*curs-annotation-delete-2/s);

    # and make sure we have the right test data set
    like ($res->content(), $other_annotation_re);
  }

  check_not_deleted($cb);

  {
    my $term_id = 'GO:0080170';
    my $uri = new URI("$root_url/annotation/delete/2");

    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), $other_annotation_re);
  }
};

done_testing;
