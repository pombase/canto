use strict;
use warnings;
use Test::More tests => 12;

use Data::Compare;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use HTTP::Cookies;

use PomCur::TestUtil;
use PomCur::Controller::Curs;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('1_curs');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();

my $app = $test_util->plack_app();

my $cookie_jar = HTTP::Cookies->new(
  file => '/tmp/pomcur_web_test_$$.cookies',
  autosave => 1,
);

my $test_name = 'Dr. Test Name';
my $test_email = 'test.name@example.com';

test_psgi $app, sub {
  my $cb = shift;

  my $root_url = "http://localhost:5000/curs/$curs_key";
  my $pub_title_fragment = "Inactivating pentapeptide insertions";

  # front page redirect
  {
    my $uri = new URI($root_url);
    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is ($res->code, 200);
    like ($res->content(), qr/<div class="submitter-update">/);
    like ($res->content(), qr/<form action="" method="post">/);
    like ($res->content(), qr/<input name="submitter_name"/);
  }

  # test submitting a name and email address
  {
    my $uri = new URI("$root_url/");
    $uri->query_form(submitter_email => $test_email,
                     submitter_name => $test_name,
                     submit => 'Submit',
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Gene upload/);
    like ($redirect_res->content(), qr/email-address.*$test_email/);
  }

  # test submitting a list of genes
  {
    my @gene_names = qw(cdc11 wtf22);

    my $uri = new URI("$root_url/");
    $uri->query_form(gene_identifiers => "@gene_names",
                     submit => 'Submit',
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Current gene: .*cdc11/);
  }

  # FIXME Test gene update
};

done_testing;
