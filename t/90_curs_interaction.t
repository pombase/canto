use strict;
use warnings;
use Test::More tests => 34;

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

  next unless $annotation_type->{category} eq 'interaction';

  test_psgi $app, sub {
    my $cb = shift;

    {
      my $uri = new URI("$root_url");
      my $req = HTTP::Request->new(GET => $uri);

      my $res = $cb->($req);

      # and make sure we have the right test data set
      like ($res->content(),
            qr/SPAC3A11.14c.*pkl1.*GO:0030133/s);
    }

    my $new_annotation = undef;
    my $new_annotation_id = undef;

    my $bait = $curs_schema->find_with_type('Gene',
                                            {
                                              primary_name => 'cdc11'
                                            });
    my $bait_id = $bait->gene_id();

    my $prey1 = $curs_schema->find_with_type('Gene',
                                            {
                                              primary_identifier => 'SPCC1739.10'
                                            });
    my $prey1_id = $prey1->gene_id();

    my $prey2 = $curs_schema->find_with_type('Gene',
                                            {
                                              primary_identifier => 'SPAC3A11.14c'
                                            });
    my $prey2_id = $prey2->gene_id();

    # test proceeding after choosing a term
    {
      my $uri = new URI("$root_url/annotation/edit/$bait_id/$annotation_type_name");

      $uri->query_form('prey' => [$prey1_id, $prey2_id],
                       'interaction-submit' => 'Proceed');

      my $req = HTTP::Request->new(GET => $uri);
      my $res = $cb->($req);

      is $res->code, 302;
      my $redirect_url = $res->header('location');

      $new_annotation_id = $PomCur::Controller::Curs::_debug_annotation_id;
      is ($redirect_url, "$root_url/annotation/evidence/$new_annotation_id");

      my $redirect_req = HTTP::Request->new(GET => $redirect_url);
      my $redirect_res = $cb->($redirect_req);

      like ($redirect_res->content(), qr/Choose evidence for /);

      $new_annotation =
        $curs_schema->find_with_type('Annotation', $new_annotation_id);

      is ($new_annotation->genes(), 1);
      is (($new_annotation->genes())[0]->primary_identifier(),
          $bait->primary_identifier());

      my $new_annotation_data = $new_annotation->data();
      my @data_prey = @{$new_annotation_data->{prey}};

      is ($data_prey[0]->{primary_identifier}, $prey1->primary_identifier());
      is ($data_prey[1]->{primary_identifier}, $prey2->primary_identifier());

      map { is ($_->{organism_full_name}, "Schizosaccharomyces pombe");
            is ($_->{organism_taxon}, 4896) } @data_prey;
    }

    # test adding evidence to an annotation
    {
      my $uri = new URI("$root_url/annotation/evidence/$new_annotation_id");
      $uri->query_form('evidence-select' => 'Dosage Rescue',
                       'evidence-proceed' => 'Proceed');

      my $req = HTTP::Request->new(GET => $uri);
      my $res = $cb->($req);

      is $res->code, 302;
      my $redirect_url = $res->header('location');

      is ($redirect_url, "$root_url");

      my $redirect_req = HTTP::Request->new(GET => $redirect_url);
      my $redirect_res = $cb->($redirect_req);

      like ($redirect_res->content(), qr/Choose curation type/);

      $new_annotation =
        $curs_schema->find_with_type('Annotation', $new_annotation_id);

      my $new_annotation_data = $new_annotation->data();
      is ($new_annotation_data->{evidence_code}, 'Dosage Rescue');
    }
  };
}

my $an_rs = $curs_schema->resultset('Annotation');
is ($an_rs->count(), 4);

done_testing;
