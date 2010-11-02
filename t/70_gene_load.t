use strict;
use warnings;
use Test::More tests => 3;

use Data::Compare;

use PomCur::TestUtil;
use PomCur::Track::GeneLoad;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('empty_db');

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @loaded_genes = $schema->resultset('Gene')->all();

is (@loaded_genes, 0);

my $test_genes_file = $test_util->root_dir() . '/t/data/pombe_genes.txt';

my $gene_load = PomCur::Track::GeneLoad->new(schema => $schema);
$gene_load->load($test_genes_file);

@loaded_genes = $schema->resultset('Gene')->all();

is(@loaded_genes, 9);

ok(grep {
  defined $_->primary_name() && $_->primary_name() eq 'cdc11' &&
    $_->product() eq 'SIN component scaffold protein, centriolin ortholog Cdc11'
} @loaded_genes);
