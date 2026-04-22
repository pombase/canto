use strict;
use warnings;
use Test::More tests => 7;
use Test::Deep;

use Canto::Chado::AlleleLookup;

use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $lookup = Canto::Chado::AlleleLookup->new(config => $test_util->config());

my $res = $lookup->lookup(gene_primary_identifier => 'SPBC12C2.02c',
                          search_string => 'ste');

my $expected_res = $Canto::TestUtil::shared_test_results{allele}{ste};

map {
  $_->{display_name} =~ s/ \(existing\)$//;
} @$expected_res;

cmp_deeply($res, $expected_res);

# search with gene constrained to a another gene
$res = $lookup->lookup(gene_primary_identifier => 'SPCC16A11.14',
                       search_string => 'ste');

cmp_deeply($res, []);

my $id_res = $lookup->lookup_by_uniquename('SPBC12C2.02c:allele-3');

cmp_deeply($id_res,
{
            'display_name' => 'ste20-c2(aaK132A,K144A)',
            'description' => 'K132A,K144A',
            'type' => 'amino acid substitution(s)',
            'name' => 'ste20-c2',
            'external_uniquename' => 'SPBC12C2.02c:allele-3',
            'gene_uniquename' => 'SPBC12C2.02c',
            'synonyms' => [],
          });

my @details_res = $lookup->lookup_by_details('SPBC12C2.02c', 'amino_acid_mutation',
                                             'K132A,K144A');

is(@details_res, 1);

cmp_deeply($details_res[0],
           {
            'description' => 'K132A,K144A',
            'name' => 'ste20-c2',
            'type' => 'amino_acid_mutation',
            'gene_systematic_id' => 'SPBC12C2.02c',
            'allele_uniquename' => 'SPBC12C2.02c:allele-3'
          });


my @canto_sys_id_res = $lookup->lookup_by_canto_systematic_id('SPBC12C2.02c:aaaa0008-1');

is (@canto_sys_id_res, 1);

cmp_deeply($canto_sys_id_res[0],
           {
             'gene_systematic_id' => 'SPBC12C2.02c',
             'allele_uniquename' => 'SPBC12C2.02c:allele-3',
             'description' => 'K132A,K144A',
             'name' => 'ste20-c2',
             'type' => 'amino_acid_mutation'
           });
