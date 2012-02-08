use strict;
use warnings;
use Test::More tests => 33;

use Plack::Test;
use Plack::Util;
use HTTP::Request::Common;
use Test::MockObject;

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

package TestState;

use Moose;

with 'PomCur::Role::MetadataAccess';
with 'PomCur::Curs::Role::GeneResultSet';
with 'PomCur::Curs::State';

package main;


my $state = TestState->new();

test_psgi $app, sub {
  my $cb = shift;

  {
    my $uri = new URI("$root_url/");

    my $req = GET $uri;
    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/Choose a gene to annotate/s);
    like ($res->content(), qr/Publication details/s);

    is($status_storage->retrieve($curs_key, 'annotation_status'),
       PomCur::Controller::Curs::CURATION_IN_PROGRESS);
  }

  my $further_information =
    "If there any information in your paper";
  my $thank_you ="Thank you for your contribution to PomBase";
  my $your_annotations = "Your annotations have been sent to the curation team for inclusion in the database";

  {
    my $uri = new URI("$root_url/finish_form");

    my $req = GET $uri;
    my $res = $cb->($req);

    is $res->code, 200;

    (my $content = $res->content()) =~ s/\s+/ /g;

    like ($content, qr/$thank_you/s);
    like ($content, qr/Your annotations will now be sent to the curation team/s);
    like ($content, qr/$further_information/s);

    is($status_storage->retrieve($curs_key, 'annotation_status'), "NEEDS_APPROVAL");
  }

  # test submitting a message on the finish form
  {
    my $test_text = "A text string";

    my $uri = new URI("$root_url/finish_form");
    $uri->query_form(finish_textarea => $test_text,
                     submit => 'Submit',
                    );

    my $req = GET $uri;
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);
    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url/finished_publication");

    my $redirect_req = GET $redirect_url;
    my $redirect_res = $cb->($redirect_req);

    (my $content = $redirect_res->content()) =~ s/\s+/ /g;

    like ($content, qr/$thank_you/s);
    like ($content, qr/$your_annotations/s);
    unlike ($content, qr/$further_information/s);

    is ($state->get_metadata($curs_schema, PomCur::Controller::Curs::MESSAGE_FOR_CURATORS_KEY),
        $test_text);

    is($status_storage->retrieve($curs_key, 'annotation_status'), "NEEDS_APPROVAL");
  }

  # check that we now redirect to the "finished" page
  {
    my $uri = new URI("$root_url/");

    my $res = $cb->(GET $uri);
    is $res->code, 200;

    (my $content = $res->content()) =~ s/\s+/ /g;

    like ($content, qr/$thank_you/s);
    like ($content, qr/$your_annotations/s);
    unlike ($content, qr/$further_information/s);
    unlike ($content, qr/Admin only:/);

    is($status_storage->retrieve($curs_key, 'annotation_status'), "NEEDS_APPROVAL");
  }

  # log in
  {
    my $first_admin_email_address = undef;
    my $first_admin_password = undef;

    {
      my $admin_role =
        $track_schema->resultset('Cvterm')->find({ name => 'admin' });

      my $admin_people =
        $track_schema->resultset('Person')->
        search({ role => $admin_role->cvterm_id() });

      my $first_admin = $admin_people->first();
      ok(defined $first_admin);

      $first_admin_email_address = $first_admin->email_address();
      $first_admin_password = $first_admin->password();
    }

    my $uri = new URI("http://localhost:5000/login");
    $uri->query_form(email_address => $first_admin_email_address,
                     password => $first_admin_password,
                     return_path => 'http://localhost:5000/',
                     submit => 'login',
                   );

    my $res = $cb->(GET $uri);
    $cookie_jar->extract_cookies($res);

    is $res->code, 302;

    my $redirect_url = $res->header('location');
    is ($redirect_url, 'http://localhost:5000/');

    my $redirect_req = GET $redirect_url;
    $cookie_jar->add_cookie_header($redirect_req);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Login successful/);
  }

  # check that admin options are shown when logged in as admin
  {
    my $uri = new URI("$root_url/");

    my $req = GET $uri;
    $cookie_jar->add_cookie_header($req);
    my $res = $cb->($req);

    is $res->code, 200;

    (my $content = $res->content()) =~ s/\s+/ /g;

    like ($content, qr/$thank_you/s);
    like ($content, qr/$your_annotations/s);
    unlike ($content, qr/$further_information/s);

    like ($content, qr/Admin only:/);

    is($status_storage->retrieve($curs_key, 'annotation_status'), "NEEDS_APPROVAL");
  }
};

done_testing;
