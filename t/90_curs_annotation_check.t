use strict;
use warnings;
use Test::More tests => 28;

use Plack::Test;
use Plack::Util;
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

my $thank_you = "Thank you for your contribution";

test_psgi $app, sub {
  my $cb = shift;

  {
    my $res = $cb->(GET "$root_url/");
    is $res->code, 200;

    like ($res->content(), qr/Annotate genes/s);
    like ($res->content(), qr/Annotate genotypes/s);
    like ($res->content(), qr/Publication details/s);

    is($status_storage->retrieve($curs_key, 'annotation_status'),
       Canto::Controller::Curs::CURATION_IN_PROGRESS);
  }

  # change status to "NEEDS_APPROVAL"
  {
    my $res = $cb->(GET "$root_url/finish_form");
    is $res->code, 200;

    is($status_storage->retrieve($curs_key, 'annotation_status'), "NEEDS_APPROVAL");
  }

  my $admin_only = "Admin only links";

  # check that we now redirect to the "finished" page
  {
    my $req = GET "$root_url/";

    my $res = $cb->($req);
    is $res->code, 200;

    (my $content = $res->content()) =~ s/\s+/ /g;

    like ($content, qr/$thank_you/s);
    unlike ($content, qr/$admin_only/s);
    is($status_storage->retrieve($curs_key, 'annotation_status'), "NEEDS_APPROVAL");
  }

  # make sure we can't start approving a session unless logged in as admin
  {
    my $req = GET "$root_url/begin_approval/";

    my $res = $cb->($req);
    $cookie_jar->extract_cookies($res);
    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url");

    my $redirect_req = GET $redirect_url;
    $cookie_jar->add_cookie_header($redirect_req);
    my $redirect_res = $cb->($redirect_req);

    (my $content = $redirect_res->content()) =~ s/\s+/ /g;

    like ($content, qr/Only admin users can approve sessions/s);
    like ($content, qr/$thank_you/s);
    unlike ($content, qr/$admin_only/s);

    is($status_storage->retrieve($curs_key, 'annotation_status'), "NEEDS_APPROVAL");
  }

  # log in
  $test_util->app_login($cookie_jar, $cb);

  # check that after log in we still show the "finished" page
  # and the admin options are visible
  {
    my $req = GET "$root_url/";
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);
    is $res->code, 200;

    (my $content = $res->content()) =~ s/\s+/ /g;

    like ($content, qr/$thank_you/s);
    like ($content, qr/$admin_only/s);
    is($status_storage->retrieve($curs_key, 'annotation_status'), "NEEDS_APPROVAL");
  }

  # check we can start approving a session when logged in as admin
  {
    my $req = GET "$root_url/begin_approval/";
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);
    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url");

    my $redirect_req = GET $redirect_url;
    $cookie_jar->add_cookie_header($redirect_req);
    my $redirect_res = $cb->($redirect_req);

    (my $content = $redirect_res->content()) =~ s/\s+/ /g;

    unlike ($content, qr/$thank_you/s);
    unlike ($content, qr/$admin_only/s);
    like ($content, qr/Session is being checked by Val Wood/s);

    is($status_storage->retrieve($curs_key, 'annotation_status'), "APPROVAL_IN_PROGRESS");
  }



  # XXX FIXME add a test for reactivating sessions


};

done_testing;
