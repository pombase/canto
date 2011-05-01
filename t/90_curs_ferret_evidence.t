use strict;
use warnings;
use Test::More tests => 132;

use Data::Compare;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use HTTP::Cookies;

use PomCur::TestUtil;
use PomCur::Controller::Curs;

my $test_util = PomCur::TestUtil->new();
my $config = $test_util->config();

$test_util->init_test('curs_annotations_1');

my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();
my $curs_schema = PomCur::Curs::get_schema_for_key($config, $curs_key);

my $app = $test_util->plack_app()->{app};

my $root_url = "http://localhost:5000/curs/$curs_key";

my @annotation_type_list = @{$config->{annotation_type_list}};

for my $annotation_type (@annotation_type_list) {
  my $annotation_type_name = $annotation_type->{name};

  next unless $annotation_type->{category} eq 'ontology';

  my $cv_name = $annotation_type->{namespace} // $annotation_type->{name};
  my $cv = $track_schema->find_with_type('Cv', { name => $cv_name });

  my $new_term = $track_schema->resultset('Cvterm')
    ->search({ is_relationshiptype => 0, cv_id => $cv->cv_id() },
             {
               order_by => 'name' })->first();

  test_psgi $app, sub {
    my $cb = shift;

    my $term_db_accession = $new_term->db_accession();
    my $new_annotation_re = qr/<td>\s*SPCC1739.10\s*<\/td>.*$term_db_accession.*IMP/s;

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


    my $new_annotation = undef;
    my $new_annotation_id = undef;

    # test proceeding after choosing a term
    {
      my $gene_id = 2;
      my $uri = new URI("$root_url/annotation/edit/$gene_id/$annotation_type_name");

      $uri->query_form('ferret-term-id' => $term_db_accession,
                       'ferret-submit' => 'Proceed',
                       'ferret-term-entry' => $new_term->name());

      my $req = HTTP::Request->new(GET => $uri);

      my $res = $cb->($req);

      is $res->code, 302;

      my $redirect_url = $res->header('location');

      $new_annotation_id = $PomCur::Controller::Curs::_debug_annotation_id;
      is ($redirect_url, "$root_url/annotation/evidence/$new_annotation_id");

      my $redirect_req = HTTP::Request->new(GET => $redirect_url);
      my $redirect_res = $cb->($redirect_req);

      my $gene = $curs_schema->find_with_type('Gene', $gene_id);
      my $gene_display_name = $gene->display_name();

      like ($redirect_res->content(),
            qr/Choose evidence for annotating $gene_display_name with $term_db_accession/);

      $new_annotation =
        $curs_schema->find_with_type('Annotation', $new_annotation_id);

      is ($new_annotation->genes(), 1);
      is (($new_annotation->genes())[0]->primary_identifier(), "SPCC1739.10");
      is ($new_annotation->data()->{term_ontid}, $new_term->db_accession());
    }

    # test adding evidence to an annotation
    {
      my $uri = new URI("$root_url/annotation/evidence/$new_annotation_id");
      $uri->query_form('evidence-select' => 'IMP',
                       'evidence-proceed' => 'Proceed');

      my $req = HTTP::Request->new(GET => $uri);

      my $res = $cb->($req);

      is $res->code, 302;

      my $redirect_url = $res->header('location');

      is ($redirect_url, "$root_url/annotation/transfer/$new_annotation_id");

      my $redirect_req = HTTP::Request->new(GET => $redirect_url);
      my $redirect_res = $cb->($redirect_req);

      like ($redirect_res->content(), qr/You can annotate other genes/);

      my $annotation =
        $curs_schema->find_with_type('Annotation', $new_annotation_id);

      is ($annotation->genes(), 1);
      is (($annotation->genes())[0]->primary_identifier(), "SPCC1739.10");
      is ($annotation->data()->{term_ontid}, $new_term->db_accession());
      is ($annotation->data()->{evidence_code}, 'IMP');
    }

    # test transferring annotation
    {
      my $cdc11 = $curs_schema->find_with_type('Gene',
                                               {
                                                 primary_name => 'cdc11' });
      my $gene_2 =
        my $uri = new URI("$root_url/annotation/transfer/$new_annotation_id");
      $uri->query_form('transfer' => 'transfer-submit',
                       dest => [$cdc11->gene_id()]);

      my $req = HTTP::Request->new(GET => $uri);
      my $res = $cb->($req);

      is $res->code, 302;

      my $redirect_url = $res->header('location');

      is ($redirect_url, "$root_url");

      my $redirect_req = HTTP::Request->new(GET => $redirect_url);
      my $redirect_res = $cb->($redirect_req);

      like ($redirect_res->content(), $new_annotation_re);

      my $annotation =
        $curs_schema->find_with_type('Annotation', $new_annotation_id);

      is ($annotation->genes(), 1);
      is (($annotation->genes())[0]->primary_identifier(), "SPCC1739.10");
      is ($annotation->data()->{term_ontid}, $new_term->db_accession());
      is ($annotation->data()->{evidence_code}, 'IMP');

      my $new_annotation =
        $curs_schema->find_with_type('Annotation', $new_annotation_id + 1);

      is ($new_annotation->genes(), 1);
      is (($new_annotation->genes())[0]->primary_identifier(), "SPCC1739.11c");
      is ($new_annotation->data()->{term_ontid}, $new_term->db_accession());
      is ($new_annotation->data()->{evidence_code}, 'IMP');
    }
  };
}

my $an_rs = $curs_schema->resultset('Annotation');
is ($an_rs->count(), 12);

done_testing;
