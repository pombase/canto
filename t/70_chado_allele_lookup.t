use strict;
use warnings;
use Test::More tests => 3;
use Test::Deep;

use Canto::Chado::AlleleLookup;

use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $lookup = Canto::Chado::AlleleLookup->new(config => $test_util->config());

my $res = $lookup->lookup(gene_primary_identifier => 'SPBC12C2.02c',
                          search_string => 'ste');

cmp_deeply($res,
           $Canto::TestUtil::shared_test_results{allele}{ste});

# search with gene constrained to a another gene
$res = $lookup->lookup(gene_primary_identifier => 'SPCC16A11.14',
                       search_string => 'ste');

cmp_deeply($res, []);

my $id_res = $lookup->lookup_by_uniquename('SPBC12C2.02c:allele-3');

cmp_deeply($id_res,
{
            'display_name' => 'ste20-c2(K132A,K144A)',
            'description' => 'K132A,K144A',
            'type' => 'amino acid substitution(s)',
            'name' => 'ste20-c2',
            'external_uniquename' => 'SPBC12C2.02c:allele-3',
            'gene_uniquename' => 'SPBC12C2.02c',
            'synonyms' => [],
          });
