use strict;
use warnings;
use Test::More tests => 10;

use Data::Compare;

use PomCur::TestUtil;
use PomCur::CursDB;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();

my $schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0007');

ok($schema);

# test inflating and deflating of data
$schema->txn_do(
  sub {
    $schema->create_with_type('Pub', { uniquename => 12345678,
                                       title => "a title",
                                       abstract => "abstract text",
                                     });
  });

my $res_pub = $schema->find_with_type('Pub', { uniquename => 12345678 });

$res_pub->update();

my $new_res_pub = $schema->find_with_type('Pub', { uniquename => 12345678 });

my $spcc576_16c = $schema->find_with_type('Gene',
                                          { primary_identifier => 'SPCC576.16c' });
is ($spcc576_16c->direct_annotations()->count(), 0);
is ($spcc576_16c->indirect_annotations(), 1);
is ($spcc576_16c->all_annotations(), 1);

my $spcc63_05 = $schema->find_with_type('Gene',
                                          { primary_identifier => 'SPCC63.05' });
is ($spcc63_05->direct_annotations()->count(), 2);
is ($spcc63_05->indirect_annotations(), 0);
is ($spcc63_05->all_annotations(), 2);

my $spbc14f5_07 = $schema->find_with_type('Gene',
                                          { primary_identifier => 'SPAC27D7.13c' });
is ($spbc14f5_07->direct_annotations()->count(), 1);
is ($spbc14f5_07->indirect_annotations(), 1);
is ($spbc14f5_07->all_annotations(), 2);

