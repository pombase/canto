use strict;
use warnings;
use Test::More tests => 1;
use Test::Deep;

use Canto::TestUtil;
use Canto::Curs::ServiceUtils;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $curs_schema);

my $res = $service_utils->list_for_service('genotype');

cmp_deeply($res,
           [
            {
              'identifier' => 'h+ SPCC63.05delta ssm4KE'
            },
            {
              'identifier' => 'h+ ssm4-D4'
            }
          ]);
