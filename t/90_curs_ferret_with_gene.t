use strict;
use warnings;
use Test::More tests => 47;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

use Canto::TestUtil;
use Canto::Controller::Curs;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_1');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $app = $test_util->plack_app()->{app};

my $root_url = "http://localhost:5000/curs/$curs_key";

test_psgi $app, sub {
  my $cb = shift;

  my $term_id = 'GO:0080170';
  my $new_annotation_re = qr|.*$term_id.*IPI.*cdc11|s;

  my $annotation_evidence_url = "$root_url/annotation/3/evidence";
  my $annotation_with_gene_url = "$root_url/annotation/3/with_gene";
  my $transfer_url = "$root_url/annotation/3/transfer";

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
    my $gene_id = 2;
    my $uri = new URI("$root_url/gene/$gene_id/new_annotation/biological_process/choose_term");
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

    my $gene = $curs_schema->find_with_type('Gene', $gene_id);
    my $gene_proxy = Canto::Controller::Curs::_get_gene_proxy($config, $gene);
    my $gene_display_name = $gene_proxy->display_name();

    like ($redirect_res->content(),
          qr/Choose evidence for annotating $gene_display_name with $term_id/);

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
                     'evidence-submit-proceed' => 'Proceed ->');

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

  # test uploading another gene
  {
    is ($curs_schema->resultset('Gene')->count(), 3);

    my $uri = new URI("$root_url/gene_upload");
    $uri->query_form(return_path_input => $annotation_with_gene_url,
                     gene_identifiers => ['ste16'],
                     Submit => 'Submit');

    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, $annotation_with_gene_url);

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    is ($curs_schema->resultset('Gene')->count(), 4);
  }

  # test going to upload gene page, then pressing back
  {
    is ($curs_schema->resultset('Gene')->count(), 4);

    my $uri = new URI("$root_url/gene_upload");
    $uri->query_form(return_path_input => $annotation_with_gene_url,
                     gene_identifiers => ['klp1'],
                     Submit => 'Back');

    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, $annotation_with_gene_url);

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    is ($curs_schema->resultset('Gene')->count(), 4);
  }

  my $with_gene_identifier = "SPCC1739.11c";
  my $with_gene =
    $curs_schema->find_with_type('Gene',
                                 { primary_identifier => $with_gene_identifier });

  # test setting "with gene"
  {
    my $uri = new URI($annotation_with_gene_url);
    $uri->query_form('with-gene-select' => $with_gene_identifier,
                     'with-gene-proceed' => 'Proceed');

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');
    is ($redirect_url, $transfer_url);

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/You can annotate other genes/);

    my $annotation =
      $curs_schema->find_with_type('Annotation', 3);

    is ($annotation->data()->{term_ontid}, 'GO:0080170');
    is ($annotation->data()->{evidence_code}, 'IPI');
    is ($annotation->data()->{with_gene}, $with_gene_identifier);
  }

  my @annotations_with_gene = ();

  # test transferring annotation
  {
    my $gene_1 =
      $curs_schema->find_with_type('Gene',
                                   {
                                     primary_identifier => 'SPCC1739.11c',
                                   });

    my $an_rs = $curs_schema->resultset('Annotation');
    is ($an_rs->count(), 3);

    while (defined (my $annotation = $an_rs->next())) {
      ok(!grep {
        $_->primary_identifier() eq $gene_1->primary_identifier()
      } $annotation->genes());
    }

    my $uri = new URI($transfer_url);
    $uri->query_form('transfer' => 'transfer-submit',
                     dest => [$gene_1->gene_id()]);

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url/gene/2/view");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    is ($an_rs->count(), 4);

    like ($redirect_res->content(), $new_annotation_re);

    my $original_annotation =
      $curs_schema->find_with_type('Annotation', 3);

    push @annotations_with_gene, $original_annotation->annotation_id();

    is ($original_annotation->data()->{term_ontid}, 'GO:0080170');
    is ($original_annotation->data()->{evidence_code}, 'IPI');
    is ($original_annotation->data()->{with_gene}, $with_gene_identifier);

    my $new_annotation =
      $curs_schema->find_with_type('Annotation', 4);

    push @annotations_with_gene, $new_annotation->annotation_id();

    is ($new_annotation->genes(), 1);
    is (($new_annotation->genes())[0]->primary_identifier(), "SPCC1739.11c");
    is ($new_annotation->data()->{term_ontid}, 'GO:0080170');
    is ($new_annotation->data()->{evidence_code}, 'IPI');
    is ($new_annotation->data()->{with_gene}, undef);
  }

  # test deleting a gene referred to by a with_gene field
  {
    my $uri = new URI("$root_url/edit_genes");
    $uri->query_form(submit => 'Remove selected',
                     'gene-select' => [$with_gene->gene_id()],
                    );

    my $req = HTTP::Request->new(GET => $uri);

    my @genes_before_delete = $curs_schema->resultset('Gene')->all();

    my $res = $cb->($req);

    is $res->code, 200;

    my @genes_after_delete = $curs_schema->resultset('Gene')->all();

    is (@genes_after_delete, @genes_before_delete - 1);

    # check that the annotations are deleted too
    ok (!defined($curs_schema->resultset('Annotation')
                 ->find($annotations_with_gene[0])));
    ok (!defined($curs_schema->resultset('Annotation')
                 ->find($annotations_with_gene[1])));
  }
};

done_testing;
