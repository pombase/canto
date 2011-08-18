use strict;
use warnings;
use Test::More tests => 6;
use Test::Deep;

use PomCur::Chado::OntologyAnnotationLookup;
use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $lookup =
  PomCur::Chado::OntologyAnnotationLookup->new(config => $test_util->config());

ok(defined $lookup->schema());

my $res = $lookup->lookup({pub_uniquename => 'PMID:10467002',
                           ontology_name => 'biological_process',
                           }
                         );

is(@$res, 1);

cmp_deeply($res->[0],
           {
             gene => {
               identifier => 'SPBC12C2.02c',
               name => 'ste20',
               organism_taxonid => '4896',
             },
             ontology_term => {
               ontid => 'GO:0006810',
               term_name => 'transport',
               ontology_name => 'biological_process'
             },
             evidence_code => 'IMP',
             with => 'GeneDB_Spombe:SPBC2G2.01c',
             from => undef,
             annotation_id => 1,
             publication => {
               uniquename => 'PMID:10467002'
             }
            });

$res = $lookup->lookup({pub_uniquename => 'PMID:10467002',
                        ontology_name => 'biological_process',
                        gene_identifier => 'SPBC12C2.02c',
                      }
                     );

is(@$res, 1);

cmp_deeply($res->[0],
           {
             gene => {
               identifier => 'SPBC12C2.02c',
               name => 'ste20',
               organism_taxonid => '4896',
             },
             ontology_term => {
               ontid => 'GO:0006810',
               term_name => 'transport',
               ontology_name => 'biological_process'
             },
             evidence_code => 'IMP',
             with => 'GeneDB_Spombe:SPBC2G2.01c',
             from => undef,
             annotation_id => 1,
             publication => {
               uniquename => 'PMID:10467002'
             }
            });

$res = $lookup->lookup({pub_uniquename => 'PMID:10467002',
                        ontology_name => 'biological_process',
                        gene_identifier => 'unknown_id',
                      }
                     );

is(@$res, 0);
