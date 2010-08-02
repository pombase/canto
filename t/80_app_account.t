use strict;
use warnings;
use Test::More;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} = 'test';

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $psgi_script_name = $test_util->root_dir() . '/script/pomcur_psgi.pl';
my $app = Plack::Util::load_psgi($psgi_script_name);

test_psgi $app, sub {
  my $cb = shift;

  my $return_path = 'http://localhost:5000/view/list/lab?model=manage';
  my $encoded_return_path = $return_path;
  $encoded_return_path =~ s/\?/%3F/g;
  $encoded_return_path =~ s/=/%3D/g;
  my $url = "http://localhost:5000/account?return_path=$encoded_return_path";

  # test visiting account page
  {
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;
    ok ($res->content() =~ /Account details/);
    ok ($res->content() =~ /User ID/);

    ok ($res->content() =~ /\Q$return_path/);
  }

  # test login
  {
    my $uri = new URI('http://localhost:5000/login');
    $uri->query_form(networkaddress => 'nick.rhind@umassmed.edu',
                     password => 'nick.rhind@umassmed.edu',
                     return_path => $return_path);

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is ($res->code, 302);
    is ($res->header('location'), $return_path);
  }
};

done_testing;
