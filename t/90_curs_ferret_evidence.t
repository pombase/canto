use strict;
use warnings;
use Test::More tests => 9;

use Data::Compare;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use HTTP::Cookies;

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

my $root_url = "http://localhost:5000/curs/$curs_key";

test_psgi $app, sub {
  my $cb = shift;

  my $term_id = 'GO:0080170';
  my $new_annotation_re = qr/<td>\s*SPCC1739.10\s*<\/td>.*$term_id.*IMP/s;

  {
    my $uri = new URI("$root_url");
    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    # make sure we actually change the list of annotations later
    unlike ($res->content(), $new_annotation_re);

    # and make sure we have the right test data set
    like ($res->content(),
          qr/SPAC3A11.14c.*pkl1.*GO:0030133/s);

  }

  # test proceeding after choosing a term
  {
    my $term_id = 'GO:0080170';
    my $uri = new URI("$root_url/annotation/edit/2/biological_process");
    $uri->query_form('ferret-term-id' => $term_id,
                     'ferret-submit' => 'Proceed',
                     'ferret-term-entry' => 'transport');

    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url/annotation/evidence/3");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Choose evidence for $term_id/);
  }

  # test adding evidence to an annotation
  {
    my $uri = new URI("$root_url/annotation/evidence/3");
    $uri->query_form('evidence-select' => 'IMP',
                     'evidence-proceed' => 'Proceed');

    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), $new_annotation_re);
  }
};

done_testing;
