use strict;
use warnings;
use Test::More tests => 4;

use Test::Deep;

use Canto::Chado::GenotypeLookup;

use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $lookup = Canto::Chado::GenotypeLookup->new(config => $test_util->config());

my $res = $lookup->lookup(gene_primary_identifiers => ['SPBC1826.01c']);

cmp_deeply($res,
           {
             results => [
               {
                 identifier => 'aaaa0007-test-genotype-2',
                 display_name => 'cdc11-33 mot1-a1',
                 allele_string => 'cdc11-33 mot1-a1',
                 name => 'cdc11-33 mot1-a1',
                 allele_identifiers => [
                   'SPCC1739.11c:allele-1', 'SPBC1826.01c:allele-1',
                 ],
                 annotation_count => 0,
               },
             ]
           });


$res = $lookup->lookup(gene_primary_identifiers => ['SPBC1826.01c', 'SPCC1739.11c']);

cmp_deeply($res,
           {
             results => [
                           {
                             'identifier' => 'aaaa0007-test-genotype-2',
                             'allele_string' => 'cdc11-33 mot1-a1',
                             'name' => 'cdc11-33 mot1-a1',
                             'display_name' => 'cdc11-33 mot1-a1',
                             allele_identifiers => [
                               'SPCC1739.11c:allele-1', 'SPBC1826.01c:allele-1',
                             ],
                             annotation_count => 0,
                           }
                         ]
           });


$res = $lookup->lookup(gene_primary_identifiers => ['SPCC1739.11c']);

cmp_deeply($res,
           {
             results => [
                           {
                             'allele_string' => 'cdc11-33',
                             'identifier' => 'aaaa0007-test-genotype-1',
                             'display_name' => 'cdc11-33',
                             'allele_identifiers' => [
                                                       'SPCC1739.11c:allele-1'
                                                     ],
                             'name' => 'cdc11-33',
                             annotation_count => 0,
                           },
                           {
                             'allele_string' => 'cdc11-33 mot1-a1',
                             'identifier' => 'aaaa0007-test-genotype-2',
                             'allele_identifiers' => [
                                                       'SPCC1739.11c:allele-1',
                                                       'SPBC1826.01c:allele-1'
                                                     ],
                             'name' => 'cdc11-33 mot1-a1',
                             'display_name' => 'cdc11-33 mot1-a1',
                             annotation_count => 0,
                           },
                           {
                             'allele_string' => 'cdc11-33 ssm4delta',
                             'identifier' => 'aaaa0007-test-genotype-3',
                             'allele_identifiers' => [
                                                       'SPCC1739.11c:allele-1',
                                                       'SPAC27D7.13c:allele-1'
                                                     ],
                             'name' => 'cdc11-33 ssm4delta',
                             'display_name' => 'cdc11-33 ssm4delta',
                             annotation_count => 1,
                           }
                         ]
           });

$res = $lookup->lookup(identifier => 'aaaa0007-test-genotype-1');

cmp_deeply($res,
           {
             'allele_string' => 'cdc11-33',
             'name' => 'cdc11-33',
             'display_name' => 'cdc11-33',
             'identifier' => 'aaaa0007-test-genotype-1',
             allele_identifiers => [
               'SPCC1739.11c:allele-1',
             ],
             annotation_count => 0,
           });
