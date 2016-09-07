use strict;
use warnings;
use Test::More tests => 66;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use Web::Scraper;

use Canto::TestUtil;
use Canto::Controller::Curs;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('1_curs');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();

my $app = $test_util->plack_app()->{app};

my $cookie_jar = $test_util->cookie_jar();

my $test_name = 'Dr. Test Name';
my $test_email = 'test.name@example.com';

my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $root_url = "http://localhost:5000/curs/$curs_key";
my $uniquename = "PMID:19664060";
my @gene_identifiers = qw(cdc11 mot1 SPNCRNA.119 klp1);

# test submitting a list of genes
sub upload_genes
{
  my $cb = shift;
  my $genes = shift;
  my $multiple_organisms = shift // 0;

  my $uri = new URI("$root_url/");
  $uri->query_form(gene_identifiers => "@$genes",
                   submit => 'Submit',
                 );

  my $req = HTTP::Request->new(GET => $uri);
  $cookie_jar->add_cookie_header($req);

  my $res = $cb->($req);
  $cookie_jar->extract_cookies($res);

  is $res->code, 302, $res->content();

  my $redirect_url = $res->header('location');

  is ($redirect_url, "$root_url/confirm_genes");

  my $redirect_req = HTTP::Request->new(GET => $redirect_url);
  $cookie_jar->add_cookie_header($redirect_req);
  my $redirect_res = $cb->($redirect_req);

  my $content = $redirect_res->content();

  like ($content, qr/Confirm gene list/);
  like ($content, qr:<span class="curs-matched-search-term">cdc11</span>:);

  if ($multiple_organisms) {
    like ($content, qr/Saccharomyces/);
    like ($content, qr/cerevisiae/);
  } else {
    unlike ($content, qr/Saccharomyces/);
    unlike ($content, qr/cerevisiae/);
  }

  my @stored_genes = $curs_schema->resultset('Gene')->all();

  if ($multiple_organisms) {
    is (@stored_genes, 5);
  } else {
    is (@stored_genes, 4);
  }

  for my $gene_identifier (@$genes) {
    my $found_match = 0;
    for my $stored_gene (@stored_genes) {
      my $stored_gene_proxy =
        Canto::Controller::Curs::_get_gene_proxy($config, $stored_gene);
      if ($stored_gene_proxy->primary_identifier() eq $gene_identifier ||
          ( defined $stored_gene_proxy->primary_name() &&
            $stored_gene_proxy->primary_name() eq $gene_identifier ) ||
            grep {
              $_ eq $gene_identifier;
            } $stored_gene_proxy->synonyms()
          ) {
        $found_match = 1;
        last;
      }
    };

    ok($found_match);
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
    like ($res->content(), qr/<div id="curs-intro/);
    like ($res->content(), qr/You are about to start curating/);
  }

  # click "Curate this paper"
  {
    my $uri = new URI("$root_url/assign_session");
    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is ($res->code, 200);
    like ($res->content(), qr/<div id="curs-assign-session"/);
    like ($res->content(), qr/Curator details/);
  }

  # test submitting a name and email address
  {
    my $uri = new URI("$root_url/assign_session");
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

    like ($redirect_res->content(), qr/Create gene list for $uniquename/);
    like ($redirect_res->content(), qr/Curated by:.{1,20}$test_email/s);
  }

  # try with and without the organism column
  upload_genes($cb, \@gene_identifiers, 0);

  $curs_schema->resultset('Gene')->delete();

  my @genes_with_cerevisiae = (@gene_identifiers, 'YHR066W');
  upload_genes($cb, \@genes_with_cerevisiae, 1);

  # test deleting genes
  {
    my @stored_genes = $curs_schema->resultset('Gene')->all();
    my @stored_gene_ids = map { $_->gene_id() } @stored_genes;

    my $uri = new URI("$root_url/edit_genes");
    $uri->query_form(submit => 'Remove selected',
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

    like ($redirect_res->content(), qr/Create gene list for $uniquename/);

    my @genes_after_delete = $curs_schema->resultset('Gene')->all();

    is (@genes_after_delete, 0);
  }

  upload_genes($cb, \@gene_identifiers, 0);

  # test deleting 1 gene
  {
    my @stored_genes = $curs_schema->resultset('Gene')->all();
    my @stored_gene_ids = map { $_->gene_id() } @stored_genes;

    my $uri = new URI("$root_url/edit_genes");
    $uri->query_form(submit => 'Remove selected',
                     'gene-select' => [$stored_gene_ids[0]],
                    );

    my $req = HTTP::Request->new(GET => $uri);

    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/Removed 1 gene from list/);
    like ($res->content(), qr/Gene list for $uniquename/);

    my @genes_after_delete = $curs_schema->resultset('Gene')->all();

    is (@genes_after_delete, 3);
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

    my $page_scrape = scraper {
      process ".curs-front-gene-list", "gene_list" => 'TEXT';
      process ".curs-front-pub-details", "pub_title" => 'TEXT';
      result 'gene_list', 'pub_title';
    };

    my $scrape_res = $page_scrape->scrape($redirect_res->content());

    like ($scrape_res->{gene_list}, qr/Annotate genes and genotypes/);
    like ($scrape_res->{pub_title}, qr/Inactivating pentapeptide insertions/);
  }

  # test the "this paper has no genes" button on the gene upload form
  {
    $curs_schema->resultset('Gene')->delete();

    my $uri = new URI("$root_url/");
    $uri->query_form();

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/Create gene list for $uniquename/);
    like ($res->content(), qr/Curated by:.{1,20}$test_email/s);

    my @genes_after_delete = $curs_schema->resultset('Gene')->all();

    is (@genes_after_delete, 0);

    $uri = new URI("$root_url/");
    $uri->query_form(gene_identifiers => "",
                     'no-genes' => 1,
                     'no-genes-reason' => 'Review',
                     submit => 'Submit',
                   );

    $req = HTTP::Request->new(GET => $uri);
    $res = $cb->($req);

    is $res->code, 302, $res->content();

    my $redirect_url = $res->header('location');
    is ($redirect_url, "$root_url/finish_form");
    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    unlike ($redirect_res->content(), qr/Create gene list for $uniquename/);
    my $thank_you ="Thank you for your contribution";
    like ($redirect_res->content(), qr/$thank_you/);
    like ($redirect_res->content(), qr/annotations will now be sent/s);
  }
};

done_testing;
