use strict;
use warnings;
use Test::More tests => 3;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

use Canto::TestUtil;

use JSON;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $app = $test_util->plack_app()->{app};

my $curs_key = 'aaaa0007';
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $root_url = "http://localhost:5000/curs/$curs_key";

my $first_genotype =
 $curs_schema->resultset('Genotype')->find({ identifier => 'aaaa0007-genotype-test-1' });

my $first_genotype_annotation = $first_genotype->annotations()->first();

my $first_genotype_annotation_id = $first_genotype_annotation->annotation_id();

test_psgi $app, sub {
  my $cb = shift;

  my $uri = new URI("$root_url/ws/annotation/$first_genotype_annotation_id/new/change");

  my $req = HTTP::Request->new(POST => $uri);
  $req->header('Content-Type' => 'application/json');
  my $new_comment = "new service comment";
  my $changes = {
    key => $curs_key,
    submitter_comment => $new_comment,
  };

  ok(!defined($first_genotype_annotation->data()->{submitter_comment}));

  $req->content(to_json($changes));

  my $res = $cb->($req);

  my $perl_res = decode_json $res->content();

  is($perl_res->{status}, 'success');

  # re-query
  $first_genotype_annotation = $first_genotype->annotations()->first();

  is ($first_genotype_annotation->data()->{submitter_comment}, "$new_comment");
};
