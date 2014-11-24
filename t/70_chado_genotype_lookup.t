use strict;
use warnings;
use Test::More tests => 2;

use Test::Deep;

use Canto::Chado::GenotypeLookup;

use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $lookup = Canto::Chado::GenotypeLookup->new(config => $test_util->config());

my $res = $lookup->lookup(gene_primary_identifiers => ['SPCC576.16c']);

cmp_deeply($res,
           {
             results => [
               {
                 primary_identifier => 'aaaa0007-genotype-2',
                 alleles => [
                   {
                     primary_identifier => '',
                     name => '',
                     description => '',
                     type => '',
                   }
                 ]
               },
             ]
           });


$res = $lookup->lookup(gene_primary_identifiers => ['SPCC576.16c', 'SPCC1739.11c']);

cmp_deeply($res,
           {
             results => [
               {
                 primary_identifier => 'aaaa0007-genotype-2',
               },
             ]
           });


$res = $lookup->lookup(gene_primary_identifiers => ['SPCC1739.11c']);

cmp_deeply($res,
           {
             results => [
               {
                 primary_identifier => 'aaaa0007-genotype-1',
               },
               {
                 primary_identifier => 'aaaa0007-genotype-2',
               },
             ]
           });


