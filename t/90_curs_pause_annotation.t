use strict;
use warnings;
use Test::More tests => 24;

use Plack::Test;
use Plack::Util;
use HTTP::Cookies;
use HTTP::Request::Common;

use Canto::TestUtil;
use Canto::Track::StatusStorage;
use Canto::Role::MetadataAccess;
use Canto::Controller::Curs;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_1');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();

my $status_storage = Canto::Track::StatusStorage->new(config => $config);

my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();
my $app = $test_util->plack_app()->{app};
my $cookie_jar = $test_util->cookie_jar();
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);
my $root_url = "http://localhost:5000/curs/$curs_key";


my $state = Canto::Curs::MetadataStorer->new(config => $config);

test_psgi $app, sub {
  my $cb = shift;

  {
    my $uri = new URI("$root_url/");

    my $req = GET $uri;
    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/Annotate genes/s);
    like ($res->content(), qr/Publication details/s);

    is($status_storage->retrieve($curs_key, 'annotation_status'),
       Canto::Controller::Curs::CURATION_IN_PROGRESS);
  }

  my $curation_paused_message = 'Your work is permanently saved';

  {
    my $uri = new URI("$root_url/pause_curation");

    my $req = GET $uri;
    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url");

    my $redirect_req = GET $redirect_url;
    my $redirect_res = $cb->($redirect_req);

    my $content = $redirect_res->content();

    like ($content, qr/$curation_paused_message/s);

    is($status_storage->retrieve($curs_key, 'annotation_status'), "CURATION_PAUSED");
  }

  # test returning that we get sent back to the pause page
  {
    my $req = GET new URI("$root_url/");

    my $res = $cb->($req);
    is $res->code, 200;

    my $content = $res->content();

    like ($content, qr/$curation_paused_message/);

    is($status_storage->retrieve($curs_key, 'annotation_status'), "CURATION_PAUSED");
  }

  # check that returning to /pause_curation doesn't fail - the user may bookmark it
  {
    my $uri = new URI("$root_url/pause_curation");

    my $res = $cb->(GET $uri);
    is $res->code, 200;

    my $content = $res->content();

    like ($content, qr/$curation_paused_message/);

    is($status_storage->retrieve($curs_key, 'annotation_status'), "CURATION_PAUSED");
  }

  # check that returning to /pause_curation doesn't fail - the user may bookmark it
  {
    my $uri = new URI("$root_url/pause_curation");

    my $res = $cb->(GET $uri);
    is $res->code, 200;

    my $content = $res->content();

    like ($content, qr/$curation_paused_message/);

    is($status_storage->retrieve($curs_key, 'annotation_status'), "CURATION_PAUSED");
  }

  # test restarting the curation
  {
    my $uri = new URI("$root_url/restart_curation/");

    my $res = $cb->(GET $uri);
    $cookie_jar->extract_cookies($res);
    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url");

    my $redirect_req = GET $redirect_url;
    $cookie_jar->add_cookie_header($redirect_req);
    my $redirect_res = $cb->($redirect_req);

    my $content = $redirect_res->content();

    unlike ($content, qr/$curation_paused_message/);

    like ($content, qr/Session has been restarted/);
    like ($content, qr/Annotate genes/);

    is($status_storage->retrieve($curs_key, 'annotation_status'), "CURATION_IN_PROGRESS");
  }
};

done_testing;
