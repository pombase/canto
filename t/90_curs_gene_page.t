use strict;
use warnings;
use Test::More tests => 4;

use Plack::Test;
use Plack::Util;

use PomCur::TestUtil;
use PomCur::Controller::Curs;

my $test_util = PomCur::TestUtil->new();
my $config = $test_util->config();

$test_util->init_test('curs_annotations_2');

my $track_schema = $test_util->track_schema();

my $curs_key = 'aaaa0007';
my $curs_schema = PomCur::Curs::get_schema_for_key($config, $curs_key);

my $app = $test_util->plack_app()->{app};

my $root_url = "http://localhost:5000/curs/$curs_key";

my $curator_manager = $test_util->curator_manager();
$curator_manager->accept_session($curs_key);

my @annotation_type_list = @{$config->{annotation_type_list}};

test_psgi $app, sub {
  my $cb = shift;

  my $gene_id = 2;
  my $uri = new URI("$root_url/gene/$gene_id");

  my $req = HTTP::Request->new(GET => $uri);
  my $res = $cb->($req);
  is $res->code, 200;

  my $gene = $curs_schema->find_with_type('Gene', $gene_id);
  my $gene_proxy = PomCur::Controller::Curs::_get_gene_proxy($config, $gene);
  my $gene_display_name = $gene_proxy->display_name();

  like ($res->content(), qr/Choose curation type for $gene_display_name/);
  like ($res->content(), qr/Epitope-tagged protein immunolocalization experiment data/);
  like ($res->content(), qr/Gene: $gene_display_name/);
};

done_testing;

