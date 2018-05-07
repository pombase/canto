use strict;
use warnings;
use Test::More tests => 15;
use Test::Deep;
use JSON;

use Capture::Tiny 'capture_stderr';
use Try::Tiny;

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


# add an organism
$service_utils->add_organism_by_taxonid(4932);

$res = $service_utils->list_for_service('organism');

is (@$res, 2);
is ($res->[0]->{full_name}, "Schizosaccharomyces pombe");
is ($res->[0]->{gene_count}, 4);
is ($res->[1]->{full_name}, "Saccharomyces cerevisiae");
is ($res->[1]->{gene_count}, 0);


# delete an organism
my $delete_res = $service_utils->delete_organism_by_taxonid(4932);

is ($delete_res->{status}, "success");

$res = $service_utils->list_for_service('organism');

is (@$res, 1);
is ($res->[0]->{full_name}, "Schizosaccharomyces pombe");
is ($res->[0]->{gene_count}, 4);


$delete_res = $service_utils->delete_organism_by_taxonid(4896);

is ($delete_res->{status}, "error");
ok ($delete_res->{message} =~ /genes/);

$res = $service_utils->list_for_service('organism');

is (@$res, 1);
