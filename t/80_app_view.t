use strict;
use warnings;
use Test::More tests => 18;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use Web::Scraper;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $track_schema = $test_util->track_schema();

my $app = $test_util->plack_app()->{app};

test_psgi $app, sub {
  my $cb = shift;

  # test viewing an object
  {
    my $url = 'http://localhost:5000/view/object/person/1?model=track';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/Details for Val Wood/);
    like ($res->content(), qr/Val Wood/);
  }

  # test viewing a more complicated object
  {
    my $test_pub = $track_schema->resultset('Pub')->find({ uniquename => 'PMID:19351719' });
    my $test_pub_id = $test_pub->pub_id();

    my $url = "http://localhost:5000/view/object/pub/$test_pub_id?model=track";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/Details for publication: PMID:19351719/);
    like ($res->content(), qr/Sequence feature or region/);
  }

  # test viewing a list
  {
    my $url = 'http://localhost:5000/view/list/lab?model=track';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $page_scrape = scraper {
      process "title", title => 'TEXT';
      process ".field-value .display-key", 'field_values[]' => 'TEXT';
      process ".page_nav_summary", row_count => 'TEXT';
    };

    my $scrape_res = $page_scrape->scrape($res->decoded_content());

    like ($scrape_res->{title}, qr/List of all labs/);
    ok (grep { /Nick Rhind/ } @{$scrape_res->{field_values}});
    like ($scrape_res->{row_count}, qr/13\b.* total/);
  }

  # test viewing a report
  {
    my $url = 'http://localhost:5000/view/list/named_genes?model=track';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;
    like ($res->content(), qr/List of named genes/);
    like ($res->content(), qr:<b>10</b> total:);
    like ($res->content(), qr/rpn501/);
    unlike ($res->content(), qr/SPBC12C2.11/);
  }

  # test sql columns
  {
    my $url = 'http://localhost:5000/view/list/cv?model=track';
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;
    like ($res->content(), qr/List of all controlled vocabularies/);
    like ($res->content(), qr/PSI-MOD.*19.*PomCur publication curation status/s);
  }
};

done_testing;
