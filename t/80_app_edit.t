use strict;
use warnings;
use Test::More tests => 27;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use HTTP::Cookies;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $app = $test_util->plack_app();

my $cookie_jar = HTTP::Cookies->new(
  file => '/tmp/pomcur_web_test_$$.cookies',
  autosave => 1,
);

my $test_name = 'Test name';
my $test_email = 'test@test';
my $test_email2 = 'new@test_email';

my $new_person_id = undef;

my $schema = $test_util->track_schema();

test_psgi $app, sub {
  my $cb = shift;

  # login
  {
    my $uri = new URI('http://localhost:5000/login');
    my $val_email = 'val@sanger.ac.uk';
    my $return_path = 'http://localhost:5000/';

    $uri->query_form(email_address => $val_email,
                     password => $val_email,
                     return_path => $return_path);

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    my $login_cookie = $res->header('set-cookie');
    $cookie_jar->extract_cookies($res);

    is ($res->code, 302);
    is ($res->header('location'), $return_path);
  }

  # test visiting the create object page
  {
    my $url = 'http://localhost:5000/new/object/person?model=track';
    my $req = HTTP::Request->new(GET => $url);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/<form/);
    like ($res->content(), qr/<input name="Email address"/);
  }

  # test creating an object
  {
    my $uri = new URI('http://localhost:5000/new/object/person');
    $uri->query_form(model => 'track',
                     name => $test_name,
                     'Email address' => $test_email,
                     lab => 0,
                     role => 1,
                     submit => 'Submit',
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    ok ($redirect_url =~ m:view/object/person/(\d+):);

    $new_person_id = $1;

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Details for Test name/);
    like ($redirect_res->content(), qr/Email address/);
    like ($redirect_res->content(), qr/\Q$test_name/);
    like ($redirect_res->content(), qr/\Q$test_email/);
  }

  # test visiting the edit object page
  {
    my $url = "http://localhost:5000/edit/object/person/$new_person_id?model=track";
    my $req = HTTP::Request->new(GET => $url);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/<form/);
    like ($res->content(), qr/<input name="Email address"/);
  }

  # test editing an object
  {
    my $test_name = 'Test name';

    my $uri = new URI("http://localhost:5000/edit/object/person/$new_person_id");
    $uri->query_form(model => 'track',
                     name => $test_name,
                     'Email address' => $test_email2,
                     lab => 0,
                     role => 1,
                     submit => 'Submit',
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Details for Test name/);
    like ($redirect_res->content(), qr/Email address/);
    unlike ($redirect_res->content(), qr/\Q$test_email/);
    like ($redirect_res->content(), qr/\Q$test_email2/);
  }

  # test create action
  {
    my $test_name = 'Test name';
    my $pub = $schema->find_with_type('Pub', { uniquename => 'PMID:19056896' });
    my $curs_key = 'abcd1234';

    my $uri = new URI("http://localhost:5000/create/curs");
    $uri->query_form(model => 'track',
                     curs_key => $curs_key,
                     pub => $pub->pub_id(),
                     curator => $new_person_id,
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Details for curation session $curs_key/);
    like ($redirect_res->content(), qr/$test_name/);
    like ($redirect_res->content(), qr/The S. pombe SAGA complex controls/);
  }


  # special case: test editing publications separately as they have a reference
  # that ends in _id ("type_id")
  {
    my $pub = $schema->find_with_type('Pub', { uniquename => 'PMID:19686603' });

    ok (defined $pub);

    my $pub_id = $pub->pub_id();

    my $url = "http://localhost:5000/new/object/pub/$pub_id?model=track";
    my $req = HTTP::Request->new(GET => $url);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/<form/);
    like ($res->content(), qr/<input name="title"/);
  }

};

done_testing;
