use strict;
use warnings;
use Test::More tests => 8;

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
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $app = $test_util->plack_app()->{app};

my $root_url = "http://localhost:5000/curs/$curs_key";

test_psgi $app, sub {
  my $cb = shift;

  my $with_gene = $curs_schema->find_with_type('Gene',
                                               primary_identifier => 'SPCC576.16c');

  ok (defined $with_gene);

  my $annotation_with_with_gene_rs = $curs_schema->resultset('Annotation');

  my $with_gene_annotation = undef;

  while (defined (my $annotation = $annotation_with_with_gene_rs->next())) {
    my $with_gene = $annotation->data()->{with_gene};

    if (defined $with_gene && $with_gene eq 'SPCC576.16c') {
      $with_gene_annotation = $annotation;
      last;
    }
  }

  ok (defined $with_gene_annotation);

  ok (defined($curs_schema->resultset('Annotation')
                 ->find($with_gene_annotation->annotation_id())));

  # test deleting a gene referred to by a with_gene field
  {
    my $uri = new URI("$root_url/edit_genes");
    $uri->query_form(submit => 'Remove selected',
                     'gene-select' => [$with_gene->gene_id()],
                    );

    my $req = HTTP::Request->new(GET => $uri);

    my $genes_before_delete = $curs_schema->resultset('Gene')->count();
    is ($genes_before_delete, 4);

    my $res = $cb->($req);

    is $res->code, 200;

    my $genes_after_delete = $curs_schema->resultset('Gene')->count();
    is ($genes_after_delete, 3);

    # check that the annotations are deleted too
    ok (!defined($curs_schema->resultset('Annotation')
                  ->find($with_gene_annotation->annotation_id())));

  }
};

done_testing;
