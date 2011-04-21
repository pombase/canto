use strict;
use warnings;
use Test::More tests => 17;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $app = $test_util->plack_app()->{app};

test_psgi $app, sub {
  my $cb = shift;

  # test searching for a non-match
  {
    my $url = 'http://localhost:15000/search/type/gene?model=track&search-term=non-match&submit=search';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    ok ($res->content() =~ /No results/);
  }

  # test searching for an exact match
  {
    my $url = 'http://localhost:15000/search/type/gene?model=track&search-term=cdc11&submit=search';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    ok ($res->content() =~ m:<b>1</b> rows found:);
    ok ($res->content() =~ /SPCC1739.11c/);
  }

  # test searching for a wildcard
  {
    my $url = 'http://localhost:15000/search/type/gene?model=track&search-term=rpn*&submit=search';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    ok ($res->content() =~ m:<b>2</b> rows found:);
    ok ($res->content() =~ /SPAC1420.03/);
    ok ($res->content() =~ /SPAPB8E5.02c/);
  }

  # test searching for a wildcard on report page
  {
    my $url = 'http://localhost:15000/search/type/named_gene?model=track&search-term=rpn*&submit=search';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    ok ($res->content() =~ m:<b>2</b> rows found:);
    ok ($res->content() =~ /rpn501/);
    ok ($res->content() =~ /rpn502/);
    ok ($res->content() !~ /ssm4/);
  }

  # test searching for a search term on report page that shouldn't be found
  {
    my $url = 'http://localhost:15000/search/type/named_gene?model=track&search-term=SPBC12C2.11&submit=search';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    ok ($res->content() =~ /You searched for: SPBC12C2.11/);
    ok ($res->content() =~ /No results/);
  }
};

done_testing;
