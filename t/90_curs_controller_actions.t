use strict;
use warnings;
use Test::More tests => 36;

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

my $test_name = 'Dr. Test Name';
my $test_email = 'test.name@example.com';

my $curs_schema = PomCur::Curs::get_schema_for_key($config, $curs_key);

my $root_url = "http://localhost:5000/curs/$curs_key";
my $pub_title_fragment = "Inactivating pentapeptide insertions";

my $uniquename = "PMID:19664060";

my @gene_identifiers = qw(cdc11 wtf22 SPCC1739.10);

# test submitting a list of genes
sub upload_genes
{
  my $cb = shift;

  my $uri = new URI("$root_url/");
  $uri->query_form(gene_identifiers => "@gene_identifiers",
                   submit => 'Submit',
                 );

  my $req = HTTP::Request->new(GET => $uri);
  $cookie_jar->add_cookie_header($req);

  my $res = $cb->($req);

  is $res->code, 302;

  my $redirect_url = $res->header('location');

  is ($redirect_url, "$root_url/confirm_genes");

  my $redirect_req = HTTP::Request->new(GET => $redirect_url);
  my $redirect_res = $cb->($redirect_req);

  like ($redirect_res->content(), qr/Gene list/);
  like ($redirect_res->content(), qr/cdc11/);

  my @stored_genes = $curs_schema->resultset('Gene')->all();
  is (@stored_genes, 3);

  for my $gene_identifier (@gene_identifiers) {
    ok (grep { $_->primary_identifier() eq $gene_identifier ||
                 ( defined $_->primary_name() &&
                     $_->primary_name() eq $gene_identifier ) } @stored_genes);
  }
}

test_psgi $app, sub {
  my $cb = shift;

  # front page redirect
  {
    my $uri = new URI($root_url);
    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is ($res->code, 200);
    like ($res->content(), qr/<div class="submitter-update">/);
    like ($res->content(), qr/<form action="" method="post">/);
    like ($res->content(), qr/<input name="submitter_name"/);
  }

  # test submitting a name and email address
  {
    my $uri = new URI("$root_url/");
    $uri->query_form(submitter_email => $test_email,
                     submitter_name => $test_name,
                     submit => 'Submit',
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Gene upload/);
    like ($redirect_res->content(), qr/email-address.*$test_email/);
  }

  upload_genes($cb);

  # test deleting genes
  {
    my @stored_genes = $curs_schema->resultset('Gene')->all();
    my @stored_gene_ids = map { $_->gene_id() } @stored_genes;

    my $uri = new URI("$root_url/edit_genes");
    $uri->query_form(submit => 'Delete selected',
                     'gene-select' => [@stored_gene_ids],
                    );

    my $req = HTTP::Request->new(GET => $uri);

    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url/gene_upload");

    my $redirect_req = HTTP::Request->new(GET =>$redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Gene upload/);

    my @genes_after_delete = $curs_schema->resultset('Gene')->all();

    is (@genes_after_delete, 0);
  }

  upload_genes($cb);

  # test deleting 1 gene
  {
    my @stored_genes = $curs_schema->resultset('Gene')->all();
    my @stored_gene_ids = map { $_->gene_id() } @stored_genes;

    my $uri = new URI("$root_url/edit_genes");
    $uri->query_form(submit => 'Delete selected',
                     'gene-select' => [$stored_gene_ids[0]],
                    );

    my $req = HTTP::Request->new(GET => $uri);

    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/Removed 1 gene from list/);
    like ($res->content(), qr/Gene list for $uniquename/);

    my @genes_after_delete = $curs_schema->resultset('Gene')->all();

    is (@genes_after_delete, 2);
  }

  # test continuing from gene edit form
  {
    my $uri = new URI("$root_url/edit_genes");
    $uri->query_form(continue => 'Continue');

    my $req = HTTP::Request->new(GET => $uri);

    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url");

    my $redirect_req = HTTP::Request->new(GET =>$redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(),
          qr/Curating\s+$gene_identifiers[0]\s+from\s+$uniquename/);
  }
};

done_testing;
