use strict;
use warnings;
use Test::More tests => 8;

use PomCur::TestUtil;
use PomCur::Track::AlleleLoad;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('empty_db');

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @loaded_genes = $schema->resultset('Gene')->all();

is (@loaded_genes, 0);

my $test_genes_file = $test_util->root_dir() . '/t/data/pombe_genes.txt';
my $test_alleles_file = $test_util->root_dir() . '/t/data/pombe_alleles.txt';

my ($organism) = PomCur::TestUtil::add_test_organisms($config, $schema);
my $gene_load = PomCur::Track::GeneLoad->new(schema => $schema,
                                             organism => $organism);

open my $fh, '<', $test_genes_file
  or die "can't open $test_genes_file: $!";
$gene_load->load($fh);
close $fh or die "can't close $test_genes_file: $!";

@loaded_genes = $schema->resultset('Gene')->all();
is(@loaded_genes, 15);

my @loaded_alleles = $schema->resultset('Allele')->all();
is(@loaded_alleles, 0);

my $allele_load = PomCur::Track::AlleleLoad->new(schema => $schema,
                                             organism => $organism);

open $fh, '<', $test_alleles_file
  or die "can't open $test_alleles_file: $!";
$allele_load->load($fh);
close $fh or die "can't close $test_alleles_file: $!";

my $allele_rs = $schema->resultset('Allele');
@loaded_alleles = $allele_rs->all();
is(@loaded_alleles, 10);

my $spbc14f5_07_allele = $allele_rs->find({ primary_identifier => 'SPBC14F5.07-allele2' });
is ($spbc14f5_07_allele->primary_name(), 'MN101');
is ($spbc14f5_07_allele->description(), 'delnt_7,nt_G879A');
is ($spbc14f5_07_allele->gene()->primary_identifier(), 'SPBC14F5.07');

# test that all alleles are removed
$allele_load->load(IO::String->new(''));

is($schema->resultset('Allele')->count(), 0);
