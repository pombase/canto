use strict;
use warnings;
use Test::More tests => 6;

use Canto::TestUtil;
use Canto::TrackDB;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $schema = Canto::TrackDB->new(config => $config);

# test getting alt_ids
my $cvterm = $schema->resultset('Cvterm')->find({ name => 'cellular process phenotype' });
ok(defined $cvterm);

my @alt_ids = $cvterm->alt_ids();
is(@alt_ids, 1);
is($alt_ids[0], 'FYPO:0000028');

my $curs = $schema->resultset('Curs')->find({ curs_key => 'aaaa0007' });

my $dummy_value = $curs->prop_value('dummy_key');
is($dummy_value, undef);

my $annotation_status = $curs->prop_value('annotation_status');
is($annotation_status, 'CURATION_IN_PROGRESS');

is($curs->prop_value('session_genes_count'), 4);
