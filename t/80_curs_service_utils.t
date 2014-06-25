use strict;
use warnings;
use Test::More tests => 3;
use Test::Deep;

use Canto::TestUtil;
use Canto::Curs::ServiceUtils;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $curs_schema,
                                                   config => $config);

my $res = $service_utils->list_for_service('genotype');

cmp_deeply($res,
           [
            {
              'identifier' => 'h+ SPCC63.05delta ssm4KE',
              'name' => undef,
              genotype_id => 1,
            },
            {
              'identifier' => 'h+ ssm4-D4',
              'name' => undef,
              genotype_id => 2,
            }
          ]);

$res = $service_utils->list_for_service('gene');

cmp_deeply($res,
           [
            {
              'primary_identifier' => 'SPCC576.16c',
              'primary_name' => 'wtf22',
               gene_id => 1,
            },
            {
              'primary_name' => 'ssm4',
              'primary_identifier' => 'SPAC27D7.13c',
               gene_id => 2,
            },
            {
              'primary_name' => 'doa10',
              'primary_identifier' => 'SPBC14F5.07',
               gene_id => 3,
            },
            {
              'primary_identifier' => 'SPCC63.05',
              'primary_name' => undef,
               gene_id => 4,
            },
          ]);

my $first_genotype =
  $curs_schema->resultset('Genotype')->find({ identifier => 'h+ SPCC63.05delta ssm4KE' });

my $first_genotype_annotation = $first_genotype->annotations()->first();

my $new_comment = "new service comment";
my $changes = {
  comment => $new_comment,
};

$res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                         'new', $changes);

# re-query
$first_genotype_annotation = $first_genotype->annotations()->first();

is ($first_genotype_annotation->data()->{comment}, $new_comment);
