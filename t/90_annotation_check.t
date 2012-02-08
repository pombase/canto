use strict;
use warnings;
use Test::More tests => 10;

use Plack::Test;
use Plack::Util;
use HTTP::Request::Common;

use PomCur::TestUtil;
use PomCur::Track::StatusStorage;
use PomCur::Role::MetadataAccess;
use PomCur::Controller::Curs;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('curs_annotations_1');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();

my $status_storage = PomCur::Track::StatusStorage->new(config => $config);

my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();
my $app = $test_util->plack_app()->{app};
my $cookie_jar = $test_util->cookie_jar();

my $curs_schema = PomCur::Curs::get_schema_for_key($config, $curs_key);
my $root_url = "http://localhost:5000/curs/$curs_key";

my $thank_you ="Thank you for your contribution to PomBase";

test_psgi $app, sub {
  my $cb = shift;

  {
    my $res = $cb->(GET "$root_url/");
    is $res->code, 200;

    like ($res->content(), qr/Choose a gene to annotate/s);
    like ($res->content(), qr/Publication details/s);

    is($status_storage->retrieve($curs_key, 'annotation_status'),
       PomCur::Controller::Curs::CURATION_IN_PROGRESS);
  }

  # change status to "NEEDS_APPROVAL"
  {
    my $res = $cb->(GET "$root_url/finish_form");
    is $res->code, 200;

    is($status_storage->retrieve($curs_key, 'annotation_status'), "NEEDS_APPROVAL");
  }

  # log in
  $test_util->app_login($cookie_jar, $cb);

  # check that we now redirect to the "finished" page
  {
    my $req = GET "$root_url/";
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);
    is $res->code, 200;

    (my $content = $res->content()) =~ s/\s+/ /g;

    like ($content, qr/$thank_you/s);
    is($status_storage->retrieve($curs_key, 'annotation_status'), "NEEDS_APPROVAL");
  }
};

done_testing;
