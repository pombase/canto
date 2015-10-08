use strict;
use warnings;
use Test::More tests => 2;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

use Canto::TestUtil;
use Canto::Controller::Curs;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $app = $test_util->plack_app()->{app};

my $root_url = "http://localhost:5000/curs/aaaa0007";

test_psgi $app, sub {
  my $cb = shift;

  {
    my $uri = new URI("$root_url/annotation_export/biological_process");

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    my $exported = '';

    $exported .= join ("	",
                       ('PomBase',
                        'SPAC27D7.13c',
                        'ssm4',
                        '',
                        'GO:0055085',
                        'PMID:19756689',
                        'IMP',
                        '',
                        'P',
                        'p150-Glued',
                        'SPAC637.01c',
                        'gene',
                        'taxon:4896',
                        '20100102',
                        'PomBase',
                        '')) . "\n";
    $exported .= join ("	",
                       ('PomBase',
                        'SPBC14F5.07',
                        'doa10',
                        '',
                        'GO:0034763',
                        'PMID:19756689',
                        'IPI',
                        'PomBase:SPCC576.16c',
                        'P',
                        'ER-localized ubiquitin ligase Doa10 (predicted)',
                        'ssm4',
                        'gene',
                        'taxon:4896',
                        '20100102',
                        'PomBase',
                        'exists_during(GO:0051329),has_substrate(PomBase:SPBC1105.11c),requires_feature(Pfam:PF00564)|exists_during(GO:0051329),has_substrate(PomBase:SPBC1105.11c)')) . "\n";

    is $res->code, 200;
    is ($res->content(), $exported);
  }
};

done_testing;
