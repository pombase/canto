use strict;
use warnings;
use Test::More tests => 2;

use Data::Compare;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use HTTP::Cookies;

use PomCur::TestUtil;
use PomCur::Controller::Curs;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('curs_annotations_1');

my $config = $test_util->config();

my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
my $curs_key = $curs_objects[0]->curs_key();
my $app = $test_util->plack_app();

my $root_url = "http://localhost:5000/curs/$curs_key";

test_psgi $app, sub {
  my $cb = shift;

  # test submitting a name and email address
  {
    my $uri = new URI("$root_url/export/annotation");

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    my $exported = join ("	", ("GeneDB_Spombe",
                                    "SPCC1739.10",
                                    "SPCC1739.10",
                                    "GO:0055085",
                                    "",
                                    "PMID:18426916",
                                    "IMP",
                                    "",
                                    "C",
                                    "conserved fungal protein",
                                    "",
                                    "gene",
                                    "taxon:4896",
                                    "20100102",
                                    "GeneDB_Spombe")) . "\n";

    is $res->code, 200;
    is ($res->content(), $exported);
  }
};

done_testing;
