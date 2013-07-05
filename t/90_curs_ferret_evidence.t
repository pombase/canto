use strict;
use warnings;
use Test::More tests => 138;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

use Canto::TestUtil;
use Canto::Controller::Curs;

my $test_util = Canto::TestUtil->new();
my $config = $test_util->config();

$test_util->init_test('curs_annotations_1');

my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $app = $test_util->plack_app()->{app};

my $root_url = "http://localhost:5000/curs/$curs_key";

my @annotation_type_list = @{$config->{annotation_type_list}};

for my $annotation_type (@annotation_type_list) {
  my $annotation_type_name = $annotation_type->{name};

  next unless $annotation_type->{category} eq 'ontology';
  next if $annotation_type->{needs_allele};

  my $cv_name = $annotation_type->{namespace} // $annotation_type->{name};
  my $cv = $track_schema->find_with_type('Cv', { name => $cv_name });

  my $new_term = $track_schema->resultset('Cvterm')
    ->search({ is_relationshiptype => 0, cv_id => $cv->cv_id() },
             {
               order_by => 'name' })->first();

  my $term_db_accession = $new_term->db_accession();

  test_psgi $app, sub {
    my $cb = shift;

    my $new_annotation_re =
      qr|$term_db_accession.*IMP|s;

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

    my $make_annotation = sub {
      my $use_term_suggestion = shift;

      my $term_db_accession = $new_term->db_accession();

      my $new_annotation_id = undef;

      # test proceeding after choosing a term
      my $gene_id = 2;
      my $uri = new URI("$root_url/gene/$gene_id/new_annotation/$annotation_type_name/choose_term");

      my %form_params = (
        'ferret-term-id' => $term_db_accession,
      );

      if ($use_term_suggestion) {
        $form_params{'ferret-suggest-name'} = 'new_suggested_name';
        $form_params{'ferret-suggest-definition'} = 'new_suggested_definition';
        $form_params{'ferret-submit'} = 'Submit suggestion';
      } else {
        $form_params{'ferret-term-entry'} = $new_term->name();
        $form_params{'ferret-submit'} = 'Proceed';
      }

      $uri->query_form(%form_params);

      my $req = HTTP::Request->new(GET => $uri);
      my $res = $cb->($req);

      is $res->code, 302;

      my $redirect_url = $res->header('location');

      $new_annotation_id = $Canto::Controller::Curs::_debug_annotation_id;
      if ($annotation_type->{needs_allele}) {
        is ($redirect_url, "$root_url/annotation/$new_annotation_id/allele_select");
      } else {
        is ($redirect_url, "$root_url/annotation/$new_annotation_id/evidence");
      }

      my $redirect_req = HTTP::Request->new(GET => $redirect_url);
      my $redirect_res = $cb->($redirect_req);

      my $gene = $curs_schema->find_with_type('Gene', $gene_id);
      my $gene_proxy = Canto::Controller::Curs::_get_gene_proxy($config, $gene);
      my $gene_display_name = $gene_proxy->display_name();

      if ($annotation_type->{needs_allele}) {
        like ($redirect_res->content(),
              qr/Specify the allele\(s\) of $gene_display_name to annotate with $term_db_accession/);
      } else {
        like ($redirect_res->content(),
              qr/Choose evidence for annotating $gene_display_name with $term_db_accession/);
      }

      my $new_annotation =
        $curs_schema->find_with_type('Annotation', $new_annotation_id);

      is ($new_annotation->genes(), 1);
      is (($new_annotation->genes())[0]->primary_identifier(), "SPCC1739.10");
      is ($new_annotation->data()->{term_ontid}, $new_term->db_accession());

      if ($use_term_suggestion) {
        is($new_annotation->data()->{term_suggestion}->{name},
           $form_params{'ferret-suggest-name'});
        is($new_annotation->data()->{term_suggestion}->{definition},
           $form_params{'ferret-suggest-definition'});
      }

      return $new_annotation_id;
    };

    # first try making an annotation with a term request/suggestion
    $make_annotation->(1);

    my $new_annotation_id = $make_annotation->(0);

    # test adding evidence to an annotation
    {
      my $uri = new URI("$root_url/annotation/$new_annotation_id/evidence");
      $uri->query_form('evidence-select' => 'IMP',
                       'evidence-submit-proceed' => 'Proceed ->');

      my $req = HTTP::Request->new(GET => $uri);

      my $res = $cb->($req);

      is $res->code, 302;

      my $redirect_url = $res->header('location');

      is ($redirect_url, "$root_url/annotation/$new_annotation_id/transfer");

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
                                                 primary_identifier => 'SPCC1739.11c',
                                               });
      my $uri = new URI("$root_url/annotation/$new_annotation_id/transfer");
      $uri->query_form('transfer' => 'transfer-submit',
                     dest => [$cdc11->gene_id()]);

      my $req = HTTP::Request->new(GET => $uri);
      my $res = $cb->($req);

      is $res->code, 302;

      my $redirect_url = $res->header('location');

      is ($redirect_url, "$root_url/gene/2/view");

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
is ($an_rs->count(), 14);

done_testing;
