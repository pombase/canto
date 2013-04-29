use strict;
use warnings;
use Test::More tests => 11;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $return_path = 'http://localhost:5000/';
my %test_app_conf = %{$test_util->plack_app(login => $return_path)};
my $app = $test_app_conf{app};
my $cookie_jar = $test_app_conf{cookie_jar};

my $schema = $test_util->track_schema();

my $pub_uniquename = "PMID:19351719";

my $pub = $schema->find_with_type('Pub',
                                  {
                                    uniquename => $pub_uniquename,
                                  });
ok($pub);
my $curator = $schema->find_with_type('Person',
                                      {
                                        name => 'Other Tester',
                                      });
ok($curator);

test_psgi $app, sub {
  my $cb = shift;

  my $curs_key = '0000ffff';

  # test visiting the create curs page
  {
    my $params = "model=track&object.curs_key=$curs_key&pub.pub_id=5";
    my $url = "http://localhost:5000/new/object/curs?$params";
    my $req = HTTP::Request->new(GET => $url);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/<form/);
    like ($res->content(), qr:<label>curs key</label>:i);
    like ($res->content(), qr /input name="curs_key" type="text" value="$curs_key"/);
  }

  my $new_object_id = undef;

  # test creating a curs
  {
    my $uri = new URI('http://localhost:5000/new/object/curs');
    $uri->query_form(model => 'track',
                     publication => $pub->pub_id(),
                     curs_key => $curs_key,
                     submit => 'Submit',
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    ok ($redirect_url =~ m:view/object/curs/(\d+):);

    $new_object_id = $1;

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Details for curation session $curs_key/);
    like ($redirect_res->content(), qr/$curs_key/);
    like ($redirect_res->content(), qr/$pub_uniquename/);
  }
};

done_testing;
