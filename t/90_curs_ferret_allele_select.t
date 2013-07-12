use strict;
use warnings;
use Test::More tests => 51;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use JSON;

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

my $annotation_type_name = 'phenotype';
my $annotation_type_config = $config->{annotation_types}->{$annotation_type_name};
my $cv_name = $annotation_type_config->{namespace};
my $cv = $track_schema->find_with_type('Cv', { name => $cv_name });

my $new_term = $track_schema->resultset('Cvterm')
  ->search({ is_relationshiptype => 0, cv_id => $cv->cv_id() },
           { order_by => 'name' })->first();

test_psgi $app, sub {
  my $cb = shift;

  my $term_db_accession = $new_term->db_accession();

  my $new_annotation_re = qr|SPCC1739.10\s*</a>\s*<\td>.*$term_db_accession.*IMP|s;

  my $new_annotation = undef;
  my $new_annotation_id = undef;

  my $gene_id = 2;
  my $gene = $curs_schema->find_with_type('Gene', $gene_id);
  my $gene_proxy = Canto::Controller::Curs::_get_gene_proxy($config, $gene);
  my $gene_display_name = $gene_proxy->display_name();

  {
    my $uri = new URI("$root_url/gene/$gene_id/new_annotation/$annotation_type_name/single_allele/choose_term");

    $uri->query_form('ferret-term-id' => $term_db_accession,
                     'ferret-submit' => 'Proceed',
                     'ferret-term-entry' => $new_term->name());

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is $res->code, 302;
    my $redirect_url = $res->header('location');

    $new_annotation_id = $Canto::Controller::Curs::_debug_annotation_id;
    is ($redirect_url, "$root_url/annotation/$new_annotation_id/allele_select");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    my $redirect_content = $redirect_res->content();

    like ($redirect_res->content(),
          qr/Choose allele\(s\) for $gene_display_name with $term_db_accession/);

    $new_annotation =
      $curs_schema->find_with_type('Annotation', $new_annotation_id);

    my $data = $new_annotation->data();

    $data->{term_suggestion} = { name => 'sugg_name',
                                 definition => 'sugg_definition' };
    $new_annotation->data($data);
    $new_annotation->update();

    is ($new_annotation->genes(), 1);
    is (($new_annotation->genes())[0]->primary_identifier(), "SPCC1739.10");
    is ($new_annotation->data()->{term_ontid}, $new_term->db_accession());
  }

  my $evidence_param = 'Western blot assay';
  my $allele_name_param = 'an_allele_name';
  my $allele_type_param = 'mutation of single amino acid residue';
  my $allele_desc_param = 'allele_desc';
  my $expression_param = 'Knockdown';
  my @conditions_param = ("glucose rich medium", "low temperature",
                          "on a Tuesday", "BOGUS:ACCESSION");

  my $do_add_allele = sub {
    my $uri = new URI("$root_url/annotation/$new_annotation_id/add_allele_action");
    $uri->query_form('curs-allele-evidence-select' => $evidence_param,
                     'curs-allele-name' => $allele_name_param,
                     'curs-allele-type' => $allele_type_param,
                     'curs-allele-description-input' => $allele_desc_param,
                     'curs-allele-expression' => $expression_param,
                     'curs-allele-condition-names' => \@conditions_param);

    my $req = HTTP::Request->new(GET => $uri);
    return $cb->($req);
  };

  # test adding an allele
  {
    my $res = $do_add_allele->();
    is $res->code, 200;

    my $annotation = $curs_schema->find_with_type('Annotation', $new_annotation_id);

    my $data = $annotation->data();
    my $alleles_in_progress = $data->{alleles_in_progress};

    is (keys %$alleles_in_progress, 1);
    my $allele_in_progress = $alleles_in_progress->{0};
    is ($allele_in_progress->{id}, 0);
    is ($allele_in_progress->{name}, $allele_name_param);
    is ($allele_in_progress->{description}, $allele_desc_param);
    is ($allele_in_progress->{expression}, $expression_param);
    is ($allele_in_progress->{evidence}, $evidence_param);
    my @conditions_from_db = @{$allele_in_progress->{conditions}};

    is (@conditions_from_db, 4);

    my $parsed_res = decode_json($res->content());

    is ($parsed_res->{id}, 0);
    is ($parsed_res->{name}, $allele_name_param);
    is ($parsed_res->{description}, $allele_desc_param);
    is ($parsed_res->{expression}, $expression_param);
    is ($parsed_res->{evidence}, $evidence_param);
    @conditions_from_db = @{$parsed_res->{conditions}};
    is (@conditions_from_db, 4);
  }

  # test removing
  {
    my $uri = new URI("$root_url/annotation/$new_annotation_id/remove_allele_action/0");

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);
    is $res->code, 200;

    my $annotation = $curs_schema->find_with_type('Annotation', $new_annotation_id);

    my $data = $annotation->data();
    my $alleles_in_progress = $data->{alleles_in_progress};

    is (keys %$alleles_in_progress, 0);

    my $parsed_res = decode_json($res->content());

    is ($parsed_res->{annotation_id}, $new_annotation_id);
    is ($parsed_res->{allele_id}, 0);
  }

  my @new_annotations = ();

  my @current_ids = map {
    $_->annotation_id();
  } $curs_schema->resultset('Annotation')->all();

  # add two alleles
  {
    # add 1
    $do_add_allele->();

    my $uri = new URI("$root_url/annotation/$new_annotation_id/add_allele_action");
    $uri->query_form('curs-allele-evidence-select' => $evidence_param,
                     'curs-allele-name' => $allele_name_param . '_2',
                     'curs-allele-type' => $allele_type_param,
                     'curs-allele-description-input' => $allele_desc_param . '_2',
                     'curs-allele-expression' => $expression_param,
                     'curs-allele-condition-names[tags][]' => ['low temperature']);

    # add another
    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is ($res->code, 200);

    {
      my $uri = new URI("$root_url/annotation/$new_annotation_id/allele_select");
      my $req = HTTP::Request->new(GET => $uri);
      my $res = $cb->($req);

      is $res->code, 200;

      my $content = $res->content();

      like ($content, qr/Choose allele\(s\) for SPCC1739.10 with FYPO:0000013 \(T-shaped cells\)/);
      like ($content, qr/glucose rich medium/);
    }

    my $annotation = $curs_schema->find_with_type('Annotation', $new_annotation_id);

    my $data = $annotation->data();
    my $alleles_in_progress = $data->{alleles_in_progress};

    is (keys %$alleles_in_progress, 2);

    $uri = new URI("$root_url/annotation/$new_annotation_id/process_alleles");
    $req = HTTP::Request->new(GET => $uri);
    $res = $cb->($req);

    is ($res->code, 302);
    my $redirect_url = $res->header('location');

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/You have made the following annotations/);

    my $rs = $curs_schema->resultset('Annotation');
    ok ($rs->count() == scalar(@current_ids) + 1);

    my $new_annotations_rs = $rs->search({ annotation_id => { -not_in => [@current_ids] }});
    is ($new_annotations_rs->count(), 2);
    @new_annotations = $new_annotations_rs->all();

    my ($allele_1_annotation, $allele_2_annotation) = @new_annotations;

    my ($allele_1, $allele_2) =
      map {
        is($_->data()->{term_suggestion}->{name}, 'sugg_name');
        $_->alleles()->first();
      } @new_annotations;

    ok (defined $allele_1);
    ok (defined $allele_2);

    if ($allele_2->name() eq $allele_name_param) {
      ($allele_1, $allele_2) = ($allele_2, $allele_1);
    }

    is ($allele_1->name(), $allele_name_param);
    is ($allele_2->name(), $allele_name_param . '_2');

    my $allele_1_display_name = $allele_1->display_name();
    like ($redirect_res->content(), qr/\Q$allele_1_display_name/);
    like ($redirect_res->content(), qr/$expression_param/);

    my $allele_2_display_name = $allele_2->display_name();
    like ($redirect_res->content(), qr/\Q$allele_2_display_name/);
  }


  {
    my $cdc11 = $curs_schema->find_with_type('Gene',
                                             {
                                               primary_identifier => 'SPCC1739.11c',
                                             });

    is ($cdc11->all_annotations(), 0);

    my $uri = new URI("$root_url/annotation/" . $new_annotations[0]->annotation_id() . '/transfer');
    $uri->query_form('dest' => [$cdc11->gene_id()],
                     'transfer-submit' => 'Finish');

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is ($res->code, 302);

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url/gene/2/view");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    is ($cdc11->all_annotations(), 1);
    my $cdc11_annotation = $cdc11->all_annotations()->first();
    is ($cdc11_annotation->data()->{term_ontid}, 'FYPO:0000013');

    like ($redirect_res->content(), qr/Choose curation type for $gene_display_name/);

    my $rs = $curs_schema->resultset('Annotation');
    ok ($rs->count() == scalar(@current_ids) + 2);

    my $conditions_param_re = "\Qglucose rich medium (PECO:0000137), low temperature (PECO:0000006), on a Tuesday (NEW), BOGUS:ACCESSION (NEW)";
    like ($redirect_res->content(), qr/$conditions_param_re/);
  }
};

done_testing;
