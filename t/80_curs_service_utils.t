use strict;
use warnings;
use Test::More tests => 49;
use Test::Deep;

use Canto::TestUtil;
use Canto::Curs::ServiceUtils;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $curs_key = 'aaaa0007';
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

$config->{implementation_classes}->{allele_adaptor} =
  'Canto::Chado::AlleleLookup';

my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $curs_schema,
                                                   config => $config);

my $res = $service_utils->list_for_service('genotype');

cmp_deeply($res,
           [
            {
              'identifier' => 'aaaa0007-genotype-1',
              'name' => 'h+ SPCC63.05delta ssm4KE',
              genotype_id => 1,
            },
            {
              'identifier' => 'aaaa0007-genotype-2',
              'name' => undef,
              genotype_id => 2,
            }
          ]);

$res = $service_utils->list_for_service('gene');

cmp_deeply($res,
           [
            {
              'primary_identifier' => 'SPCC576.16c',
              'primary_name' => 'wtf22',
               gene_id => 1,
            },
            {
              'primary_name' => 'ssm4',
              'primary_identifier' => 'SPAC27D7.13c',
               gene_id => 2,
            },
            {
              'primary_name' => 'doa10',
              'primary_identifier' => 'SPBC14F5.07',
               gene_id => 3,
            },
            {
              'primary_identifier' => 'SPCC63.05',
              'primary_name' => undef,
               gene_id => 4,
            },
          ]);

my $gene_identifier = 'SPBC14F5.07';
my $genotype_identifier = 'aaaa0007-genotype-1';

my $first_gene =
  $curs_schema->resultset('Gene')->find({ primary_identifier => $gene_identifier });
my $first_genotype =
  $curs_schema->resultset('Genotype')->find({ identifier => $genotype_identifier });

my $first_gene_annotation = $first_gene->direct_annotations()->first();
my $first_genotype_annotation = $first_genotype->annotations()->first();

my $c2d7_identifier = 'SPAC27D7.13c';
my $c2d7_gene = $curs_schema->resultset('Gene')->find({ primary_identifier => $c2d7_identifier });

my $new_comment = "new service comment";
my $changes = {
  key => $curs_key,
  submitter_comment => $new_comment,
};

$res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                         'new', $changes);

is ($res->{status}, 'success');
is ($res->{annotation}->{term_ontid}, 'FYPO:0000013');
is ($res->{annotation}->{genotype_identifier}, $genotype_identifier);
is ($res->{annotation}->{submitter_comment}, $new_comment);

# re-query
$first_genotype_annotation = $first_genotype->annotations()->first();

is ($first_genotype_annotation->data()->{submitter_comment}, $new_comment);


# test change a term
$res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                         'new',
                                         {
                                           key => $curs_key,
                                           term_ontid => 'FYPO:0000133'
                                         });
is ($res->{status}, 'success');
# re-query
$first_genotype_annotation = $first_genotype->annotations()->first();
is ($first_genotype_annotation->data()->{term_ontid}, "FYPO:0000133");
is ($res->{annotation}->{term_ontid}, 'FYPO:0000133');
is ($res->{annotation}->{term_name}, 'elongated multinucleate cells');


# test setting evidence_code
$res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                         'new',
                                         {
                                           key => $curs_key,
                                           evidence_code => "IDA",
                                         });
is ($res->{status}, 'success');
# re-query
$first_genotype_annotation = $first_genotype->annotations()->first();
is ($first_genotype_annotation->data()->{evidence_code}, "IDA");
is ($res->{annotation}->{with_or_from_identifier}, undef);

# test setting conditions
my $new_conditions = [
  {
    name => 'low temperature',
  },
  {
    name => 'some free text cond',
  }
];
$res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                         'new',
                                         {
                                           key => $curs_key,
                                           conditions => $new_conditions,
                                         });
is ($res->{status}, 'success');
# re-query
$first_genotype_annotation = $first_genotype->annotations()->first();
my @res_conditions = @{$first_genotype_annotation->data()->{conditions}};

cmp_deeply(\@res_conditions, ['PECO:0000006', 'some free text cond']);


# test illegal evidence_code
$res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                         'new',
                                         {
                                           key => $curs_key,
                                           evidence_code => "illegal",
                                         });
is ($res->{status}, 'error');
is ($res->{message}, 'no such evidence code: illegal');


# test illegal curs_key
$res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                         'new',
                                         {
                                           key => 'illegal',
                                           evidence_code => "IDA",
                                         });
is ($res->{status}, 'error');
is ($res->{message}, 'incorrect key');


# test illegal field type
$res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                         'new',
                                         {
                                           key => $curs_key,
                                           illegal => "something",
                                         });
is ($res->{status}, 'error');
is ($res->{message}, 'no such annotation field type: illegal');


# test setting with_gene/with_or_from_identifier for a gene
$res = $service_utils->change_annotation($first_gene_annotation->annotation_id(),
                                         'new',
                                         {
                                           key => $curs_key,
                                           submitter_comment => 'a short comment',
                                           with_gene_id => $c2d7_gene->gene_id(),
                                         });
is ($res->{status}, 'success');
is ($res->{annotation}->{with_or_from_identifier}, $c2d7_gene->primary_identifier());
is ($res->{annotation}->{submitter_comment}, 'a short comment');

# re-query
$first_genotype_annotation = $first_genotype->annotations()->first();
is ($first_genotype_annotation->data()->{evidence_code}, "IDA");



# create a new Annotation
is ($c2d7_gene->direct_annotations()->count(), 1);

$res = $service_utils->create_annotation({
                                           key => $curs_key,
                                           feature_id => $c2d7_gene->gene_id(),
                                           feature_type => 'gene',
                                           annotation_type => 'molecular_function',
                                           term_ontid => 'GO:0022857',
                                           evidence_code => 'IDA',
                                         });
is ($res->{status}, 'success');
is ($res->{annotation}->{gene_identifier}, $c2d7_identifier);
is ($res->{annotation}->{annotation_type}, 'molecular_function');
is ($res->{annotation}->{term_ontid}, 'GO:0022857');
is ($res->{annotation}->{term_name}, 'transmembrane transporter activity');
is ($res->{annotation}->{evidence_code}, 'IDA');
is ($res->{annotation}->{submitter_comment}, undef);
is ($res->{annotation}->{curator}, 'Some Testperson <some.testperson@pombase.org>');

is ($c2d7_gene->direct_annotations()->count(), 2);

my $new_annotation_id = $res->{annotation}->{annotation_id};

my $new_annotation = $curs_schema->find_with_type('Annotation', $new_annotation_id);
is ($new_annotation->data()->{term_ontid}, 'GO:0022857');


# test lack of information
$res = $service_utils->create_annotation({
                                           key => $curs_key,
                                         });
is ($res->{status}, 'error');
is ($res->{message}, 'No feature_id passed to annotation creation service');

# delete
$res = $service_utils->delete_annotation({
                                           key => $curs_key,
                                           annotation_id => $new_annotation_id,
                                         });

is ($c2d7_gene->direct_annotations()->count(), 1);
is ($curs_schema->resultset('Annotation')->search({ annotation_id => $new_annotation_id })->count(), 0);


# test interaction annotation services

my $genetic_interaction_annotation =
  $curs_schema->resultset('Annotation')->find({ type => 'genetic_interaction',
                                                data => { -like => '%Far Western%' } });


# test illegal field type
$res = $service_utils->change_annotation($genetic_interaction_annotation->annotation_id(),
                                         'new',
                                         {
                                           key => $curs_key,
                                           illegal => "something",
                                         });

is ($res->{status}, 'error');
is ($res->{message}, 'no such annotation field type: illegal');


# test editing
$res = $service_utils->change_annotation($genetic_interaction_annotation->annotation_id(),
                                         'new',
                                         {
                                           key => $curs_key,
                                           interacting_gene_id => 3,
                                         });

is ($res->{status}, 'success');
cmp_deeply ($res->{annotation},
            {
              'publication_uniquename' => 'PMID:19756689',
              'interacting_gene_taxonid' => 4896,
              'score' => '',
              'annotation_id' => $genetic_interaction_annotation->annotation_id(),
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'feature_id' => 4,
              'interacting_gene_identifier' => 'SPBC14F5.07',
              'interacting_gene_display_name' => 'doa10',
              'gene_display_name' => 'SPCC63.05',
              'gene_id' => 4,
              'feature_display_name' => 'SPCC63.05',
              'gene_taxonid' => 4896,
              'is_inferred_annotation' => 0,
              'gene_identifier' => 'SPCC63.05',
              'evidence_code' => 'Far Western',
              'interacting_gene_id' => 3,
              'status' => 'new',
              'completed' => 1,
              'submitter_comment' => '',
              'phenotypes' => '',
              'annotation_type' => 'genetic_interaction'
            }
          );


# test condition list service
my $cond_res = $service_utils->list_for_service('condition');

cmp_deeply($cond_res, [ { term_id => 'PECO:0000006', name => 'low temperature' },
                        { name => 'some free text cond' } ]);


# test annotation list service
my $annotation_res = $service_utils->list_for_service('annotation');

cmp_deeply($annotation_res,
           [
            {
              'evidence_code' => 'IDA',
              'creation_date' => '2010-01-02',
              'with_gene_id' => undef,
              'gene_identifier' => 'SPBC14F5.07',
              'gene_name' => 'doa10',
              'with_or_from_display_name' => undef,
              'submitter_comment' => undef,
              'feature_type' => 'gene',
              'feature_display_name' => 'doa10',
              'term_ontid' => 'GO:0022857',
              'gene_id' => 3,
              'gene_synonyms_string' => 'ssm4',
              'term_name' => 'transmembrane transporter activity',
              'is_not' => 0,
              'taxonid' => 4896,
              'creation_date_short' => '20100102',
              'completed' => 1,
              'annotation_type_display_name' => 'GO molecular function',
              'needs_with' => undef,
              'annotation_type_abbreviation' => 'F',
              'term_suggestion' => undef,
              'is_obsolete_term' => 0,
              'gene_name_or_identifier' => 'doa10',
              'feature_id' => 3,
              'publication_uniquename' => 'PMID:19756689',
              'gene_product' => 'ER-localized ubiquitin ligase Doa10 (predicted)',
              'annotation_extension' => '',
              'annotation_type' => 'molecular_function',
              'status' => 'new',
              'annotation_id' => 3,
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'with_or_from_identifier' => undef,
              'qualifiers' => ''
            },
            {
              'submitter_comment' => undef,
              'gene_name' => 'ssm4',
              'with_or_from_display_name' => undef,
              'with_gene_id' => undef,
              'gene_identifier' => 'SPAC27D7.13c',
              'creation_date' => '2010-01-02',
              'evidence_code' => 'IMP',
              'annotation_type_display_name' => 'GO biological process',
              'taxonid' => 4896,
              'completed' => 1,
              'creation_date_short' => '20100102',
              'is_not' => 0,
              'gene_synonyms_string' => 'SPAC637.01c',
              'term_name' => 'transmembrane transport',
              'term_ontid' => 'GO:0055085',
              'gene_id' => 2,
              'feature_display_name' => 'ssm4',
              'feature_type' => 'gene',
              'gene_name_or_identifier' => 'ssm4',
              'is_obsolete_term' => 0,
              'term_suggestion' => {
                                     'name' => 'miscellaneous transmembrane transport',
                                     'definition' => 'The process in which miscellaneous stuff is transported from one side of a membrane to the other.'
                                   },
              'annotation_type_abbreviation' => 'P',
              'needs_with' => undef,
              'qualifiers' => '',
              'with_or_from_identifier' => undef,
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'annotation_extension' => '',
              'annotation_type' => 'biological_process',
              'gene_product' => 'p150-Glued',
              'status' => 'new',
              'annotation_id' => 1,
              'feature_id' => 2,
              'publication_uniquename' => 'PMID:19756689'
            },
            {
              'annotation_id' => 2,
              'annotation_extension' => 'annotation_extension=exists_during(GO:0051329),annotation_extension=has_substrate(PomBase:SPBC1105.11c),annotation_extension=requires_feature(Pfam:PF00564),residue=T31,residue=T586(T586,X123),qualifier=NOT,condition=PECO:0000012,allele=SPAC9.02cdelta(deletion)|annotation_extension=exists_during(GO:0051329),has_substrate(PomBase:SPBC1105.11c)',
              'gene_product' => 'ER-localized ubiquitin ligase Doa10 (predicted)',
              'annotation_type' => 'biological_process',
              'status' => 'new',
              'publication_uniquename' => 'PMID:19756689',
              'feature_id' => 3,
              'qualifiers' => '',
              'with_or_from_identifier' => 'SPAC27D7.13c',
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'needs_with' => '1',
              'gene_name_or_identifier' => 'doa10',
              'is_obsolete_term' => 0,
              'term_suggestion' => undef,
              'annotation_type_abbreviation' => 'P',
              'gene_synonyms_string' => 'ssm4',
              'term_name' => 'negative regulation of transmembrane transport',
              'gene_id' => 3,
              'term_ontid' => 'GO:0034763',
              'feature_display_name' => 'doa10',
              'feature_type' => 'gene',
              'annotation_type_display_name' => 'GO biological process',
              'creation_date_short' => '20100102',
              'completed' => 1,
              'taxonid' => 4896,
              'is_not' => 0,
              'creation_date' => '2010-01-02',
              'evidence_code' => 'IPI',
              'submitter_comment' => 'a short comment',
              'with_or_from_display_name' => 'ssm4',
              'gene_name' => 'doa10',
              'gene_identifier' => 'SPBC14F5.07',
              'with_gene_id' => 2
            },
            {
              'evidence_code' => 'UNK',
              'gene_name_or_identifier' => 'ste20',
              'with_or_from_display_name' => undef,
              'gene_name' => 'ste20',
              'conditions' => [],
              'gene_identifier' => 'SPBC12C2.02c',
              'term_name' => 'transport [requires_direct_regulator] SPCC1739.11c',
              'term_ontid' => 'GO:0006810',
              'annotation_id' => 2,
              'annotation_type' => 'biological_process',
              'status' => 'existing',
              'feature_display_name' => 'ste20',
              'gene_product' => '',
              'feature_type' => 'gene',
              'qualifiers' => '',
              'with_or_from_identifier' => undef,
              'taxonid' => '4896',
              'is_not' => 0
            },
            {
              'evidence_code' => 'IMP',
              'gene_name' => 'ste20',
              'with_or_from_display_name' => 'PomBase:SPBC2G2.01c',
              'gene_name_or_identifier' => 'ste20',
              'gene_identifier' => 'SPBC12C2.02c',
              'conditions' => [],
              'term_ontid' => 'GO:0030133',
              'term_name' => 'transport vesicle',
              'feature_type' => 'gene',
              'feature_display_name' => 'ste20',
              'status' => 'existing',
              'gene_product' => '',
              'annotation_type' => 'cellular_component',
              'annotation_id' => 1,
              'qualifiers' => '',
              'is_not' => 0,
              'with_or_from_identifier' => 'PomBase:SPBC2G2.01c',
              'taxonid' => '4896'
            },
            {
              'term_ontid' => 'FYPO:0000133',
              'term_name' => 'elongated multinucleate cells',
              'feature_type' => 'genotype',
              'feature_display_name' => 'h+ SPCC63.05delta ssm4KE',
              'annotation_type_display_name' => 'phenotype',
              'is_not' => 0,
              'completed' => 1,
              'creation_date_short' => '20100102',
              'taxonid' => undef,
              'creation_date' => '2010-01-02',
              'evidence_code' => 'IDA',
              'genotype_id' => 1,
              'with_or_from_display_name' => undef,
              'genotype_display_name' => 'h+ SPCC63.05delta ssm4KE',
              'submitter_comment' => 'new service comment',
              'with_gene_id' => undef,
              'conditions' => [
                                {
                                  'name' => 'low temperature',
                                  'term_id' => 'PECO:0000006'
                                },
                                {
                                  'name' => 'some free text cond'
                                }
                              ],
              'publication_uniquename' => 'PMID:19756689',
              'feature_id' => 1,
              'annotation_id' => 6,
              'annotation_extension' => '',
              'annotation_type' => 'phenotype',
              'status' => 'new',
              'qualifiers' => '',
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'with_or_from_identifier' => undef,
              'needs_with' => undef,
              'genotype_name' => 'h+ SPCC63.05delta ssm4KE',
              'term_suggestion' => undef,
              'is_obsolete_term' => 0,
              'genotype_identifier' => 'aaaa0007-genotype-1',
              'annotation_type_abbreviation' => ''
            },
            {
              'evidence_code' => 'Co-immunoprecipitation experiment',
              'genotype_id' => 2,
              'creation_date' => '2010-01-02',
              'with_gene_id' => undef,
              'conditions' => [],
              'with_or_from_display_name' => undef,
              'genotype_display_name' => 'ssm4-D4(del_100-200)-partial_deletion,_nucleotide',
              'submitter_comment' => undef,
              'feature_type' => 'genotype',
              'feature_display_name' => 'ssm4-D4(del_100-200)-partial_deletion,_nucleotide',
              'term_ontid' => 'FYPO:0000017',
              'term_name' => 'elongated cells',
              'is_not' => 0,
              'completed' => 1,
              'creation_date_short' => '20100102',
              'taxonid' => undef,
              'annotation_type_display_name' => 'phenotype',
              'needs_with' => undef,
              'genotype_identifier' => 'aaaa0007-genotype-2',
              'annotation_type_abbreviation' => '',
              'genotype_name' => undef,
              'term_suggestion' => undef,
              'is_obsolete_term' => 0,
              'publication_uniquename' => 'PMID:19756689',
              'feature_id' => 2,
              'annotation_id' => 7,
              'annotation_type' => 'phenotype',
              'annotation_extension' => '',
              'status' => 'new',
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'with_or_from_identifier' => undef,
              'qualifiers' => ''
            },
            {
              'term_ontid' => 'FYPO:0000104',
              'term_name' => 'sensitive to cycloheximide',
              'feature_type' => 'gene',
              'annotation_id' => 3,
              'status' => 'existing',
              'annotation_type' => 'fission_yeast_phenotype',
              'gene_product' => '',
              'feature_display_name' => 'ste20',
              'qualifiers' => '',
              'allele_display_name' => 'ste20delta(del_x1)',
              'is_not' => 0,
              'with_or_from_identifier' => undef,
              'taxonid' => '4896',
              'evidence_code' => 'UNK',
              'with_or_from_display_name' => undef,
              'gene_name' => 'ste20',
              'gene_name_or_identifier' => 'ste20',
              'gene_identifier' => 'SPBC12C2.02c',
              'conditions' => []
            },
            {
              'evidence_code' => 'ISS',
              'creation_date' => '2010-01-02',
              'with_gene_id' => undef,
              'gene_identifier' => 'SPCC63.05',
              'submitter_comment' => undef,
              'gene_name' => '',
              'with_or_from_display_name' => undef,
              'feature_display_name' => 'SPCC63.05',
              'feature_type' => 'gene',
              'term_name' => 'protein modification categorized by amino acid modified',
              'gene_synonyms_string' => '',
              'term_ontid' => 'MOD:01157',
              'gene_id' => 4,
              'taxonid' => 4896,
              'creation_date_short' => '20100102',
              'completed' => '',
              'is_not' => 0,
              'annotation_type_display_name' => 'protein modification',
              'needs_with' => '1',
              'annotation_type_abbreviation' => '',
              'gene_name_or_identifier' => 'SPCC63.05',
              'is_obsolete_term' => 0,
              'term_suggestion' => undef,
              'annotation_extension' => '',
              'annotation_type' => 'post_translational_modification',
              'gene_product' => 'TAP42 family protein involved in TOR signalling (predicted)',
              'status' => 'new',
              'annotation_id' => 8,
              'feature_id' => 4,
              'publication_uniquename' => 'PMID:19756689',
              'with_or_from_identifier' => undef,
              'curator' => 'Another Testperson <a.n.other.testperson@pombase.org>',
              'qualifiers' => ''
            },
            {
              'interacting_gene_display_name' => 'doa10',
              'evidence_code' => 'Synthetic Haploinsufficiency',
              'interacting_gene_taxonid' => 4896,
              'gene_taxonid' => 4896,
              'submitter_comment' => '',
              'is_inferred_annotation' => 0,
              'gene_identifier' => 'SPCC63.05',
              'gene_id' => 4,
              'gene_display_name' => 'SPCC63.05',
              'publication_uniquename' => 'PMID:19756689',
              'feature_id' => 4,
              'score' => '',
              'annotation_id' => 4,
              'feature_display_name' => 'SPCC63.05',
              'status' => 'new',
              'annotation_type' => 'genetic_interaction',
              'phenotypes' => '',
              'interacting_gene_id' => 3,
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'interacting_gene_identifier' => 'SPBC14F5.07',
              'completed' => 1
            },
            {
              'phenotypes' => '',
              'completed' => 1,
              'interacting_gene_identifier' => 'SPBC14F5.07',
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'interacting_gene_id' => 3,
              'gene_display_name' => 'SPCC63.05',
              'gene_id' => 4,
              'feature_display_name' => 'SPCC63.05',
              'status' => 'new',
              'annotation_type' => 'genetic_interaction',
              'score' => '',
              'annotation_id' => 5,
              'feature_id' => 4,
              'publication_uniquename' => 'PMID:19756689',
              'gene_taxonid' => 4896,
              'submitter_comment' => '',
              'interacting_gene_taxonid' => 4896,
              'gene_identifier' => 'SPCC63.05',
              'is_inferred_annotation' => 0,
              'interacting_gene_display_name' => 'doa10',
              'evidence_code' => 'Far Western'
            },
            {
              'evidence_code' => 'Phenotypic Enhancement',
              'publication_uniquename' => 'PMID:19756689',
              'status' => 'existing',
              'gene_display_name' => 'ste20',
              'interacting_gene_display_name' => 'cdc11',
              'gene_identifier' => 'SPBC12C2.02c',
              'interacting_gene_identifier' => 'SPCC1739.11c',
              'interacting_gene_taxonid' => '4896',
              'gene_taxonid' => '4896'
            },
            {
              'interacting_gene_display_name' => 'sfh1',
              'gene_display_name' => 'ste20',
              'status' => 'existing',
              'evidence_code' => undef,
              'publication_uniquename' => 'PMID:19756689',
              'gene_taxonid' => '4896',
              'interacting_gene_taxonid' => '4896',
              'interacting_gene_identifier' => 'SPCC16A11.14',
              'gene_identifier' => 'SPBC12C2.02c'
            }
          ]);


# read from CursDB
my $allele_res = $service_utils->list_for_service('allele', 'SPAC27D7.13c', 'ssm');

cmp_deeply($allele_res,
           [
             {
               'description' => 'deletion',
               'allele_type' => 'deletion',
               'name' => 'ssm4delta',
               'uniquename' => 'SPAC27D7.13c:aaaa0007-1',
               'expression' => undef,
               'display_name' => 'ssm4delta(deletion)',
             },
             {
               'description' => 'G40A,K43E',
               'allele_type' => 'mutation of single amino acid residue',
               'expression' => undef,
               'uniquename' => 'SPAC27D7.13c:aaaa0007-2',
               'name' => 'ssm4KE',
               'display_name' => 'ssm4KE(G40A,K43E)',
             },
             {
               'expression' => undef,
               'name' => 'ssm4-D4',
               'uniquename' => 'SPAC27D7.13c:aaaa0007-3',
               'allele_type' => 'partial deletion, nucleotide',
               'description' => 'del_100-200',
               'display_name' => 'ssm4-D4(del_100-200)',
             }
           ]);

$allele_res = $service_utils->list_for_service('allele', 'SPBC12C2.02c', 'ste');

cmp_deeply($allele_res,
           [
             {
               'display_name' => 'ste20-c1(K132A)',
               'description' => 'K132A',
               'allele_type' => 'mutation of single amino acid residue',
               'uniquename' => 'SPBC12C2.02c:allele-2',
               'name' => 'ste20-c1',
             },
             {
               'name' => 'ste20-c2',
               'uniquename' => 'SPBC12C2.02c:allele-3',
               'description' => 'K132A,K144A',
               'allele_type' => 'mutation of multiple amino acid residues',
               'display_name' => 'ste20-c2(K132A,K144A)'
             },
             {
               'display_name' => 'ste20delta(del_x1)',
               'description' => 'del_x1',
               'allele_type' => 'deletion',
               'uniquename' => 'SPBC12C2.02c:allele-1',
               'name' => 'ste20delta'
             }
           ]);
