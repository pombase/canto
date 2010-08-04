use strict;
use warnings;
use Test::More tests => 9;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use HTTP::Cookies;

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} = 'test';

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $psgi_script_name = $test_util->root_dir() . '/script/pomcur_psgi.pl';
my $app = Plack::Util::load_psgi($psgi_script_name);

my $cookie_jar = HTTP::Cookies->new(
  file => '/tmp/pomcur_web_test_$$.cookies',
  autosave => 1,
);

test_psgi $app, sub {
  my $cb = shift;

  # login
  {
    my $uri = new URI('http://localhost:5000/login');
    my $val_email = 'val@sanger.ac.uk';
    my $return_path = 'http://localhost:5000/';

    $uri->query_form(networkaddress => $val_email,
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
    my $url = 'http://localhost:5000/new/object/person?model=manage';
    my $req = HTTP::Request->new(GET => $url);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 200;

    ok ($res->content() =~ /<form/);
    ok ($res->content() =~ /<input name="Email address"/);
  }

  # test creating an object
  {
    my $test_name = 'Test name';

    my $uri = new URI('http://localhost:5000/new/object/person');
    $uri->query_form(model => 'manage',
                     name => $test_name,
                     'Email address' => 'test@test',
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

    ok ($redirect_res->content() =~ /Details for person 19/);
    ok ($redirect_res->content() =~ /Email address/);
    ok ($redirect_res->content() =~ /\Q$test_name/);
  }
};

done_testing;
