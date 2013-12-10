use strict;
use warnings;
use Test::More tests => 2;
use Test::Deep;

use Canto::TestUtil;
use Canto::Curs::ServiceUtils;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $curs_schema);

my $res = $service_utils->list_for_service('genotype');

cmp_deeply([
            {
              'name' => 'h+ SPCC63.05-unk ssm4delta'
            },
            {
              'name' => 'h+ ssm4-D4'
            }
          ], $res);

is($service_utils->json_list_for_service('genotype'),
   '[{"name":"h+ SPCC63.05-unk ssm4delta"},{"name":"h+ ssm4-D4"}]');
