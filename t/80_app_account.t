use strict;
use warnings;
use Test::More;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request::Common;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $app = $test_util->plack_app()->{app};

my $cookie_jar = $test_util->cookie_jar();

test_psgi $app, sub {
  my $cb = shift;

  my $return_path = 'http://localhost:5000/view/list/lab?model=track';
  my $encoded_return_path = $return_path;
  $encoded_return_path =~ s/\?/%3F/g;
  $encoded_return_path =~ s/=/%3D/g;
  my $url = "http://localhost:5000/account?return_path=$encoded_return_path";

  # test visiting account page
  {
    my $res = $cb->(GET $url);

    is $res->code, 200;
    ok ($res->content() =~ /Log in to continue/);
    ok ($res->content() =~ /User ID/);

    ok ($res->content() =~ /\Q$return_path/);
  }

  # test login
  {
    my $uri = new URI('http://localhost:5000/login');
    $uri->query_form(email_address => 'nick.rhind@umassmed.edu',
                     password => 'nick.rhind@umassmed.edu',
                     return_path => $return_path);

    my $res = $cb->(GET $uri);
    $cookie_jar->extract_cookies($res);

    is ($res->code, 302);

    my $redirect_url = $res->header('location');
    is ($redirect_url, $return_path);

    my $redirect_req = GET $redirect_url;
    $cookie_jar->add_cookie_header($redirect_req);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Login successful/);
  }
};

done_testing;
