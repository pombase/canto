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
           [
            {
              'description' => 'K132A',
              'uniquename' => 'SPBC12C2.02c:allele-2',
              'name' => 'ste20-c1',
              'display_name' => 'ste20-c1(K132A)',
              'type' => 'mutation of single amino acid residue'
            },
            {
              'uniquename' => 'SPBC12C2.02c:allele-3',
              'name' => 'ste20-c2',
              'display_name' => 'ste20-c2(K132A,K144A)',
              'type' => 'mutation of multiple amino acid residues',
              'description' => 'K132A,K144A'
            },
            {
              'name' => 'ste20delta',
              'uniquename' => 'SPBC12C2.02c:allele-1',
              'type' => 'deletion',
              'display_name' => 'ste20delta(del_x1)',
              'description' => 'del_x1'
            }
         ]);

# search with gene constrained to a another gene
$res = $lookup->lookup(gene_primary_identifier => 'SPCC16A11.14',
                       search_string => 'ste');

cmp_deeply($res, []);

my $id_res = $lookup->lookup_by_uniquename('SPBC12C2.02c:allele-3');

cmp_deeply($id_res,
{
            'display_name' => 'ste20-c2(K132A,K144A)',
            'description' => 'K132A,K144A',
            'type' => 'amino_acid_mutation',
            'name' => 'ste20-c2',
            'uniquename' => 'SPBC12C2.02c:allele-3',
            'gene_uniquename' => 'SPBC12C2.02c',
          });
