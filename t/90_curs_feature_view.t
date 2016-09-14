use strict;
use warnings;
use Test::More tests => 18;

use Plack::Test;
use Plack::Util;

use Canto::TestUtil;
use Canto::Controller::Curs;

my $test_util = Canto::TestUtil->new('t/chado_test_config.yaml');
$test_util->init_test('curs_annotations_2', { test_with_chado => 1 });
my $config = $test_util->config();


my $track_schema = $test_util->track_schema();

my $curs_key = 'aaaa0007';
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $app = $test_util->plack_app()->{app};

my $root_url = "http://localhost:5000/curs/$curs_key";

my @annotation_type_list = @{$config->{annotation_type_list}};

test_psgi $app, sub {
  my $cb = shift;

  my $gene_id = 2;
  my $uri = new URI("$root_url/feature/gene/view/$gene_id");

  my $req = HTTP::Request->new(GET => $uri);
  my $res = $cb->($req);
  is $res->code, 200;

  my $gene = $curs_schema->find_with_type('Gene', $gene_id);
  my $gene_proxy = Canto::Controller::Curs::_get_gene_proxy($config, $gene);
  my $gene_display_name = $gene_proxy->display_name();

  like ($res->content(), qr/Choose curation type for $gene_display_name/);
  like ($res->content(), qr/Gene: $gene_display_name/);
};

test_psgi $app, sub {
  my $cb = shift;

  {
    my $genotype_id = 1;
    my $uri = new URI("$root_url/feature/genotype/view/$genotype_id");

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);
    is $res->code, 200;

    like ($res->content(), qr/Annotate normal or abnormal phenotypes of cells/);
  }

  {
    # try a genotype from Chado which should be added to the CursDB when viewed

    my $cdc11_33 = $curs_schema->resultset('Allele')
      ->find({
        name => 'cdc11-33',
      });

    ok (!defined ($cdc11_33));

    my $uri = new URI("$root_url/feature/genotype/view/aaaa0007-test-genotype-2");

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);
    is $res->code, 200;

    like ($res->content(), qr/cdc11-33 mot1-a1/);
    like ($res->content(), qr/cdc11-33\(unknown\)/);
    like ($res->content(), qr/mot1-a1\(aaT11C\)/);
    like ($res->content(), qr/Annotate normal or abnormal phenotypes of cells/);

    # re-fetch
    $cdc11_33 = $curs_schema->resultset('Allele')
      ->find({
        name => 'cdc11-33',
      });

    is ($cdc11_33->primary_identifier(), 'SPCC1739.11c:aaaa0007-1');

    my $new_genotype = $curs_schema->resultset('Genotype')
      ->find({
        identifier => 'aaaa0007-test-genotype-2',
      });

    is ($new_genotype->name(), 'cdc11-33 mot1-a1');

    is ($new_genotype->alleles(), 2);

    map {
      if ($_->name() eq 'cdc11-33') {
        is ($_->primary_identifier(), 'SPCC1739.11c:aaaa0007-1');
        is ($_->gene()->primary_identifier(), 'SPCC1739.11c');
      } else {
        if ($_->name() eq 'mot1-a1') {
          is ($_->primary_identifier(), 'SPBC1826.01c:aaaa0007-1');
          is ($_->gene()->primary_identifier(), 'SPBC1826.01c');
        } else {
          fail "unknown allele: ", $_->name();
        }
      }
    } $new_genotype->alleles();
  }
};

done_testing;

