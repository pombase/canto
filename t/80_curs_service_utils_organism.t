use strict;
use warnings;
use Test::More tests => 3;
use Test::Deep;
use JSON;

use Capture::Tiny 'capture_stderr';

use Canto::TestUtil;
use Canto::Track;
use Canto::Curs::ServiceUtils;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $curs_key = 'aaaa0007';
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $curs_schema,
                                                   config => $config);

my $res = $service_utils->list_for_service('organism');

is (@$res, 1);
is ($res->[0]->{full_name}, "Schizosaccharomyces pombe");
is ($res->[0]->{gene_count}, 4);


$service_utils->
