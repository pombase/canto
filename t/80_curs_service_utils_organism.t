use strict;
use warnings;
use Test::More tests => 20;
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

my @res_genes = @{$res->[0]->{genes}};
is (scalar(@res_genes), 4);

cmp_deeply(\@res_genes,
           [
                       {
            'gene_id' => 1,
            'display_name' => 'mot1',
            'primary_identifier' => 'SPBC1826.01c',
            'primary_name' => 'mot1'
          },
          {
            'primary_name' => 'ssm4',
            'primary_identifier' => 'SPAC27D7.13c',
            'display_name' => 'ssm4',
            'gene_id' => 2
          },
          {
            'primary_name' => 'doa10',
            'primary_identifier' => 'SPBC14F5.07',
            'gene_id' => 3,
            'display_name' => 'doa10'
          },
          {
            'primary_identifier' => 'SPCC63.05',
            'primary_name' => undef,
            'gene_id' => 4,
            'display_name' => 'SPCC63.05'
          }
        ]);

# add an organism
$service_utils->add_organism_by_taxonid(4932);

$res = $service_utils->list_for_service('organism');

is (@$res, 2);
is ($res->[0]->{full_name}, "Schizosaccharomyces pombe");
is (scalar(@{$res->[0]->{genes}}), 4);
is ($res->[1]->{full_name}, "Saccharomyces cerevisiae");
is (scalar(@{$res->[1]->{genes}}), 0);


# delete an organism
my $delete_res = $service_utils->delete_organism_by_taxonid(4932);

is ($delete_res->{status}, "success");

$res = $service_utils->list_for_service('organism');

is (@$res, 1);
is ($res->[0]->{full_name}, "Schizosaccharomyces pombe");
is (scalar(@{$res->[0]->{genes}}), 4);


$delete_res = $service_utils->delete_organism_by_taxonid(4896);

is ($delete_res->{status}, "error");
ok ($delete_res->{message} =~ /genes/);

$res = $service_utils->list_for_service('organism');

is (@$res, 1);


# test getting counts

$res = $service_utils->list_for_service('organism', { include_counts => 1 });

is (@$res, 1);
is ($res->[0]->{full_name}, "Schizosaccharomyces pombe");

@res_genes = @{$res->[0]->{genes}};
is (scalar(@res_genes), 4);

is ($res_genes[1]->{genotype_count}, 2);

