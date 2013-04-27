use strict;
use warnings;
use Test::More tests => 8;

use IO::String;

use PomCur::TestUtil;
use PomCur::Track::GeneLoad;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('empty_db');

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @loaded_genes = $schema->resultset('Gene')->all();

is (@loaded_genes, 0);

my $test_genes_file = $test_util->root_dir() . '/t/data/pombe_genes.txt';

my ($organism) = PomCur::TestUtil::add_test_organisms($config, $schema);
my $gene_load = PomCur::Track::GeneLoad->new(schema => $schema,
                                             organism => $organism);

open my $fh, '<', $test_genes_file
  or die "can't open $test_genes_file: $!";

$gene_load->load($fh);

close $fh or die "can't close $test_genes_file: $!";

@loaded_genes = $schema->resultset('Gene')->all();

ok(grep {
  defined $_->primary_name() && $_->primary_name() eq 'cdc11' &&
    $_->product() eq 'SIN component scaffold protein, centriolin ortholog Cdc11'
} @loaded_genes);

my $pkl1 = $schema->find_with_type('Gene', { primary_name => 'pkl1' });

is ($pkl1->primary_identifier(), 'SPAC3A11.14c');
my @pkl1_synonyms = sort map { $_->identifier() } $pkl1->genesynonyms()->all();
is (@pkl1_synonyms, 2);
is ($pkl1_synonyms[0], 'SPAC3H5.03c');
is ($pkl1_synonyms[1], 'klp1');

# test that all genes and synonyms are removed
$gene_load->load(IO::String->new(''));

is($schema->resultset('Gene')->count(), 0);
is($schema->resultset('Genesynonym')->count(), 0);
