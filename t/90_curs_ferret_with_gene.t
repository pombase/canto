use strict;
use warnings;
use Test::More tests => 35;

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
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();
my $curs_schema = PomCur::Curs::get_schema_for_key($config, $curs_key);

my $app = $test_util->plack_app()->{app};

my $root_url = "http://localhost:5000/curs/$curs_key";

test_psgi $app, sub {
  my $cb = shift;

  my $term_id = 'GO:0080170';
  my $new_annotation_re =
    qr/<td>\s*SPCC1739.10\s*<\/td>.*$term_id.*IPI.*cdc11/s;

  my $annotation_evidence_url = "$root_url/annotation/evidence/3";
  my $annotation_with_gene_url = "$root_url/annotation/with_gene/3";

  {
    my $uri = new URI("$root_url");
    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    # make sure we actually change the list of annotations later
    unlike ($res->content(), $new_annotation_re);

    # and make sure we have the right test data set
    like ($res->content(),
          qr/SPAC3A11.14c.*pkl1.*GO:0030133/s);
  }

  # test proceeding after choosing a term
  {
    my $term_id = 'GO:0080170';
    my $uri = new URI("$root_url/annotation/edit/2/biological_process");
    $uri->query_form('ferret-term-id' => $term_id,
                     'ferret-submit' => 'Proceed',
                     'ferret-term-entry' => 'transport');

    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, $annotation_evidence_url);

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Choose evidence for $term_id/);

    my $annotation =
      $curs_schema->find_with_type('Annotation', 3);

    is ($annotation->genes(), 1);
    is (($annotation->genes())[0]->primary_identifier(), "SPCC1739.10");
    is ($annotation->data()->{term_ontid}, 'GO:0080170');
  }

  # test adding evidence to an annotation
  {
    my $uri = new URI($annotation_evidence_url);
    $uri->query_form('evidence-select' => 'IPI',
                     'evidence-proceed' => 'Proceed');

    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, $annotation_with_gene_url);

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    my $annotation =
      $curs_schema->find_with_type('Annotation', 3);

    is ($annotation->data()->{term_ontid}, 'GO:0080170');
    is ($annotation->data()->{evidence_code}, 'IPI');
  }

  # test setting "with gene"
  {
    my $uri = new URI($annotation_with_gene_url);
    $uri->query_form('with-gene-select' => 'SPCC1739.11c',
                     'with-gene-proceed' => 'Proceed');

    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url/annotation/transfer/3");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/You can annotate other genes/);

    my $annotation =
      $curs_schema->find_with_type('Annotation', 3);

    is ($annotation->data()->{term_ontid}, 'GO:0080170');
    is ($annotation->data()->{evidence_code}, 'IPI');
    is ($annotation->data()->{with_gene}, 'SPCC1739.11c');
  }

  # test transferring annotation
  {
    my $gene_1 =
      $curs_schema->find_with_type('Gene',
                                   { primary_name => 'cdc11' });

    my $an_rs = $curs_schema->resultset('Annotation');
    is ($an_rs->count(), 3);

    while (defined (my $annotation = $an_rs->next())) {
      ok(!grep {
        $_->primary_identifier() eq $gene_1->primary_identifier()
      } $annotation->genes());
    }

    my $uri = new URI("$root_url/annotation/transfer/3");
    $uri->query_form('transfer' => 'transfer-submit',
                     dest => [$gene_1->gene_id()]);

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    is ($an_rs->count(), 4);

    like ($redirect_res->content(), $new_annotation_re);

    my $original_annotation =
      $curs_schema->find_with_type('Annotation', 3);

    is ($original_annotation->data()->{term_ontid}, 'GO:0080170');
    is ($original_annotation->data()->{evidence_code}, 'IPI');
    is ($original_annotation->data()->{with_gene}, 'SPCC1739.11c');

    my $new_annotation =
      $curs_schema->find_with_type('Annotation', 4);

    is ($new_annotation->genes(), 1);
    is (($new_annotation->genes())[0]->primary_name(), "cdc11");
    is ($new_annotation->data()->{term_ontid}, 'GO:0080170');
    is ($new_annotation->data()->{evidence_code}, 'IPI');
    is ($new_annotation->data()->{with_gene}, 'SPCC1739.11c');
  }
};

done_testing;
