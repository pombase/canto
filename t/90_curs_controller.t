use strict;
use warnings;
use Test::More tests => 31;

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

my @known_genes = qw(SPCC1739.10 wtf22 SPNCRNA.119);
my @unknown_genes = qw(dummy SPCC999999.99);

my $curs_schema = PomCur::Curs::get_schema_for_key($config, $curs_key);

my $curs_metadata_rs = $curs_schema->resultset('Metadata');

my %metadata = ();

while (defined (my $metadata = $curs_metadata_rs->next())) {
  $metadata{$metadata->key()} = $metadata->value();
}

is($metadata{first_contact}, 'nick.rhind@umassmed.edu');
is($metadata{pub_pubmedid}, 19664060);
like($metadata{pub_title}, qr/Inactivating pentapeptide insertions in the/);


my @search_list = (@known_genes, @unknown_genes);

my $result =
  PomCur::Controller::Curs::_find_and_create_genes($curs_schema, $config,
                                                   \@search_list);
sub check_result
{
  my $result = shift;
  my $missing_count = shift;
  my $found_count = shift;
  my $gene_count = shift;

  my @res_missing = @{$result->{missing}};
  my @res_found = @{$result->{found}};

  is(@res_missing, $missing_count);

  ok(Compare(\@res_missing, \@unknown_genes));
  is(@res_found, $found_count);

  ok(grep { $_->gene_id() == 7 } @res_found);

  is($curs_schema->resultset('Gene')->count(), $gene_count);
}

check_result($result, 2, 3, 0);

$result =
  PomCur::Controller::Curs::_find_and_create_genes($curs_schema, $config,
                                                   \@search_list);

check_result($result, 2, 3, 0);

$result =
  PomCur::Controller::Curs::_find_and_create_genes($curs_schema, $config,
                                                   \@known_genes);

ok(!defined $result);

is($curs_schema->resultset('Gene')->count(), 3);


sub _lookup_gene
{
  my $primary_identifier = shift;

  my @genes =
    $track_schema->find_with_type('Gene',
                                  { primary_identifier => $primary_identifier });

  die if @genes != 1;

  return $genes[0];
}

my @gene_identifiers_to_filter = ('SPCC1739.11c', $known_genes[0], $known_genes[2]);

my @genes_to_filter =
  map { _lookup_gene($_)} @gene_identifiers_to_filter;

my @filtered_genes =
  PomCur::Controller::Curs::_filter_existing_genes($curs_schema,
                                                   @genes_to_filter);

is(@filtered_genes, 1);

is($filtered_genes[0]->primary_identifier(), 'SPCC1739.11c');

$result =
  PomCur::Controller::Curs::_find_and_create_genes($curs_schema, $config,
                                                   [@known_genes, 'SPCC576.19c']);

ok(!defined $result);

is($curs_schema->resultset('Gene')->count(), 4);

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

    is ($res->code, 302);
    is ($res->header('location'), "$root_url/submitter_update");
  }

  # test that submitter_update doesn't redirect
  {
    my $req = HTTP::Request->new(GET => "$root_url/submitter_update");
    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/<form/);
    like ($res->content(), qr/<input name="submitter_email"/);
    unlike ($res->content(), qr/$pub_title_fragment/);
  }

  # test submitting a name and email address
  {
    my $uri = new URI("$root_url/submitter_update");
    $uri->query_form(submitter_email => $test_email,
                     submitter_name => $test_name,
                     submit => 'Submit',
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url/home");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    ok ($redirect_res->content(), qr/Home/);

    # publication title
    ok ($redirect_res->content(), qr/$pub_title_fragment/);
    ok ($redirect_res->content(), qr/\Q$test_email/);
  }

  # FIXME Test gene update
};

done_testing;
