use strict;
use warnings;
use Test::More tests => 4;

use Plack::Test;
use Plack::Util;

use Canto::TestUtil;
use Canto::Controller::Curs;

my $test_util = Canto::TestUtil->new();
my $config = $test_util->config();

$test_util->init_test('curs_annotations_2');

my $track_schema = $test_util->track_schema();

my $curs_key = 'aaaa0007';
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $app = $test_util->plack_app()->{app};

my $root_url = "http://localhost:5000/curs/$curs_key";

my @annotation_type_list = @{$config->{annotation_type_list}};

test_psgi $app, sub {
  my $cb = shift;

  my $gene_id = 2;
  my $uri = new URI("$root_url/gene/$gene_id/view");

  my $req = HTTP::Request->new(GET => $uri);
  my $res = $cb->($req);
  is $res->code, 200;

  my $gene = $curs_schema->find_with_type('Gene', $gene_id);
  my $gene_proxy = Canto::Controller::Curs::_get_gene_proxy($config, $gene);
  my $gene_display_name = $gene_proxy->display_name();

  like ($res->content(), qr/Choose curation type for $gene_display_name/);
  like ($res->content(), qr/Epitope-tagged protein immunolocalization experiment data/);
  like ($res->content(), qr/Gene: $gene_display_name/);
};

done_testing;

