use strict;
use warnings;
use Test::More tests => 19;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

use Canto::TestUtil;
use Canto::Controller::Curs;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 2);

my $curs_key = 'aaaa0007';

my $app = $test_util->plack_app()->{app};
my $cookie_jar = $test_util->cookie_jar();

my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $root_url = "http://localhost:5000/curs/$curs_key";

my $delete_annotation_re =
  qr/SPBC14F5.07.*GO:0034763.*IPI.*wtf22/s;
my $other_annotation_re =
  qr/SPAC27D7.13c.*GO:0055085.*IMP/s;

test_psgi $app, sub {
  my $cb = shift;

  sub check_not_deleted {
    my $cb = shift;
    my $uri = new URI("$root_url");
    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    # make sure we actually change the list of annotations later
    like ($res->content(), qr/$delete_annotation_re.*curs-annotation-delete-2/s);

    # and make sure we have the right test data set
    like ($res->content(), $other_annotation_re);
  }

  check_not_deleted($cb);

  sub delete_and_get_content {
    my $cb = shift;
    my $annotation_id = shift;
    my $interactor_identifier = shift;

    my $uri_string = "$root_url/annotation/delete/$annotation_id";
    if (defined $interactor_identifier) {
      $uri_string .= "/$interactor_identifier";
    }
    my $uri = new URI($uri_string);
    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);
    $cookie_jar->extract_cookies($res);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    $cookie_jar->add_cookie_header($redirect_req);
    my $redirect_res = $cb->($redirect_req);

    return $redirect_res->content();
  }

  is($curs_schema->resultset('Annotation')->search({ type => 'genetic_interaction' })->count(), 2);

  my $content = delete_and_get_content($cb, 2);

  like ($content, $other_annotation_re);
  unlike ($content, $delete_annotation_re);

  # delete the same annotation again to make sure we get an error
  $content = delete_and_get_content($cb, 2);
  like ($content, qr/No annotation found with id &quot;2&quot;/);

  is($curs_schema->resultset('Annotation')->search({ type => 'genetic_interaction' })->count(), 2);

  my $interaction_annotation =
    $curs_schema->resultset('Annotation')->search({
      type => 'genetic_interaction',
    })->first();
  my $ev_code = 'Synthetic Haploinsufficiency';
  my $interactor_to_delete = 'SPAC27D7.13c';


  ok (defined $interaction_annotation);
  $content = delete_and_get_content($cb, $interaction_annotation->annotation_id(),
                                    $interactor_to_delete);
  # re-fetch from database:
  $interaction_annotation->discard_changes();
  my $data = $interaction_annotation->data();

  is (@{$data->{interacting_genes}}, 1);
  ok (!grep { $_->{primary_identifier} eq $interactor_to_delete } @{$data->{interacting_genes}});

  my $all_annotation_rs = $curs_schema->resultset('Annotation');
  is($all_annotation_rs->count(), 6);

  my $interactor_to_delete_gene =
    $curs_schema->resultset('Gene')->find({ primary_identifier => $interactor_to_delete });
  $interactor_to_delete_gene->delete();

  is($all_annotation_rs->count(), 2);

  my $interaction_annotation_rs =
    $curs_schema->resultset('Annotation')->search({ type => 'genetic_interaction' });
  is($interaction_annotation_rs->count(), 0);

  my $doa10_gene = $curs_schema->resultset('Gene')->find({ primary_identifier => 'SPBC14F5.07' });
  $doa10_gene->delete();

  is($all_annotation_rs->count(), 1);
  # deleting second interactor does delete the annotation
  is($interaction_annotation_rs->count(), 0);
};

done_testing;
