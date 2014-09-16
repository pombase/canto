use strict;
use warnings;
use Test::More tests => 47;
use Test::Deep;

use Canto::TestUtil;
use Canto::Curs::ServiceUtils;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $curs_key = 'aaaa0007';
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $curs_schema,
                                                   config => $config);

my $res = $service_utils->list_for_service('genotype');

cmp_deeply($res,
           [
            {
              'identifier' => 'h+ SPCC63.05delta ssm4KE',
              'name' => undef,
              genotype_id => 1,
            },
            {
              'identifier' => 'h+ ssm4-D4',
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
my $genotype_identifier = 'h+ SPCC63.05delta ssm4KE';

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
              'publication_uniquename' => 'PMID:19756689',
              'gene_synonyms_string' => 'ssm4',
              'is_not' => 0,
              'annotation_type_display_name' => 'GO molecular function',
              'completed' => 1,
              'feature_id' => 3,
              'annotation_extension' => '',
              'gene_name' => 'doa10',
              'term_name' => 'transmembrane transporter activity',
              'status' => 'new',
              'feature_type' => 'gene',
              'annotation_id' => 3,
              'gene_identifier' => 'SPBC14F5.07',
              'submitter_comment' => undef,
              'creation_date_short' => '20100102',
              'with_or_from_identifier' => undef,
              'annotation_type' => 'molecular_function',
              'gene_name_or_identifier' => 'doa10',
              'feature_display_name' => 'doa10',
              'gene_id' => 3,
              'taxonid' => 4896,
              'with_or_from_display_name' => undef,
              'gene_product' => 'ER-localized ubiquitin ligase Doa10 (predicted)',
              'with_gene_id' => undef,
              'term_suggestion' => undef,
              'needs_with' => undef,
              'evidence_code' => 'IDA',
              'annotation_type_abbreviation' => 'F',
              'term_ontid' => 'GO:0022857',
              'is_obsolete_term' => 0,
              'creation_date' => '2010-01-02',
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'qualifiers' => ''
            },
            {
              'gene_id' => 2,
              'taxonid' => 4896,
              'gene_name_or_identifier' => 'ssm4',
              'feature_display_name' => 'ssm4',
              'annotation_type' => 'biological_process',
              'creation_date_short' => '20100102',
              'with_or_from_identifier' => undef,
              'qualifiers' => '',
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'annotation_type_abbreviation' => 'P',
              'evidence_code' => 'IMP',
              'term_ontid' => 'GO:0055085',
              'is_obsolete_term' => 0,
              'creation_date' => '2010-01-02',
              'gene_product' => 'p150-Glued',
              'with_or_from_display_name' => undef,
              'with_gene_id' => undef,
              'term_suggestion' => {
                                     'name' => 'miscellaneous transmembrane transport',
                                     'definition' => 'The process in which miscellaneous stuff is transported from one side of a membrane to the other.'
                                   },
              'needs_with' => undef,
              'status' => 'new',
              'completed' => 1,
              'annotation_extension' => '',
              'feature_id' => 2,
              'gene_name' => 'ssm4',
              'term_name' => 'transmembrane transport',
              'gene_synonyms_string' => 'SPAC637.01c',
              'is_not' => 0,
              'annotation_type_display_name' => 'GO biological process',
              'publication_uniquename' => 'PMID:19756689',
              'gene_identifier' => 'SPAC27D7.13c',
              'submitter_comment' => undef,
              'annotation_id' => 1,
              'feature_type' => 'gene'
            },
            {
              'term_suggestion' => undef,
              'needs_with' => '1',
              'with_gene_id' => 2,
              'with_or_from_display_name' => 'ssm4',
              'gene_product' => 'ER-localized ubiquitin ligase Doa10 (predicted)',
              'qualifiers' => '',
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'creation_date' => '2010-01-02',
              'is_obsolete_term' => 0,
              'term_ontid' => 'GO:0034763',
              'annotation_type_abbreviation' => 'P',
              'evidence_code' => 'IPI',
              'annotation_type' => 'biological_process',
              'with_or_from_identifier' => 'SPAC27D7.13c',
              'creation_date_short' => '20100102',
              'taxonid' => 4896,
              'gene_id' => 3,
              'feature_display_name' => 'doa10',
              'gene_name_or_identifier' => 'doa10',
              'annotation_id' => 2,
              'feature_type' => 'gene',
              'submitter_comment' => 'a short comment',
              'gene_identifier' => 'SPBC14F5.07',
              'is_not' => 0,
              'annotation_type_display_name' => 'GO biological process',
              'gene_synonyms_string' => 'ssm4',
              'publication_uniquename' => 'PMID:19756689',
              'status' => 'new',
              'term_name' => 'negative regulation of transmembrane transport',
              'feature_id' => 3,
              'annotation_extension' => 'annotation_extension=exists_during(GO:0051329),annotation_extension=has_substrate(PomBase:SPBC1105.11c),annotation_extension=requires_feature(Pfam:PF00564),residue=T31,residue=T586(T586,X123),qualifier=NOT,condition=PECO:0000012,allele=SPAC9.02cdelta(deletion)|annotation_extension=exists_during(GO:0051329),has_substrate(PomBase:SPBC1105.11c)',
              'gene_name' => 'doa10',
              'completed' => 1
            },
            {
              'gene_name_or_identifier' => 'ste20',
              'gene_name' => 'ste20',
              'term_name' => 'transport [requires_direct_regulator] SPCC1739.11c',
              'taxonid' => '4896',
              'status' => 'existing',
              'with_or_from_identifier' => undef,
              'conditions' => [],
              'annotation_type' => 'biological_process',
              'is_not' => 0,
              'evidence_code' => 'UNK',
              'term_ontid' => 'GO:0006810',
              'gene_identifier' => 'SPBC12C2.02c',
              'qualifiers' => '',
              'annotation_id' => 2,
              'with_or_from_display_name' => undef,
              'gene_product' => ''
            },
            {
              'annotation_id' => 1,
              'gene_product' => '',
              'with_or_from_display_name' => 'PomBase:SPBC2G2.01c',
              'qualifiers' => '',
              'gene_identifier' => 'SPBC12C2.02c',
              'evidence_code' => 'IMP',
              'term_ontid' => 'GO:0030133',
              'is_not' => 0,
              'annotation_type' => 'cellular_component',
              'conditions' => [],
              'with_or_from_identifier' => 'PomBase:SPBC2G2.01c',
              'taxonid' => '4896',
              'status' => 'existing',
              'term_name' => 'transport vesicle',
              'gene_name_or_identifier' => 'ste20',
              'gene_name' => 'ste20'
            },
            {
              'publication_uniquename' => 'PMID:19756689',
              'genotype_identifier' => 'h+ SPCC63.05delta ssm4KE',
              'is_not' => 0,
              'annotation_type_display_name' => 'phenotype',
              'genotype_id' => 1,
              'term_name' => 'elongated multinucleate cells',
              'feature_id' => 1,
              'annotation_extension' => '',
              'completed' => 1,
              'status' => 'new',
              'feature_type' => 'genotype',
              'genotype_name' => undef,
              'annotation_id' => 6,
              'submitter_comment' => 'new service comment',
              'with_or_from_identifier' => undef,
              'creation_date_short' => '20100102',
              'annotation_type' => 'phenotype',
              'conditions' => [
                                {
                                  'name' => 'low temperature',
                                  'term_id' => 'PECO:0000006'
                                },
                                {
                                  'name' => 'some free text cond'
                                }
                              ],
              'feature_display_name' => 'h+ SPCC63.05delta ssm4KE',
              'taxonid' => undef,
              'needs_with' => undef,
              'term_suggestion' => undef,
              'genotype_display_name' => 'h+ SPCC63.05delta ssm4KE',
              'with_gene_id' => undef,
              'with_or_from_display_name' => undef,
              'creation_date' => '2010-01-02',
              'is_obsolete_term' => 0,
              'term_ontid' => 'FYPO:0000133',
              'annotation_type_abbreviation' => '',
              'evidence_code' => 'IDA',
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'qualifiers' => ''
            },
            {
              'creation_date' => '2010-01-02',
              'is_obsolete_term' => 0,
              'term_ontid' => 'FYPO:0000017',
              'evidence_code' => 'Co-immunoprecipitation experiment',
              'annotation_type_abbreviation' => '',
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'qualifiers' => '',
              'needs_with' => undef,
              'genotype_display_name' => 'h+ ssm4-D4',
              'term_suggestion' => undef,
              'with_gene_id' => undef,
              'with_or_from_display_name' => undef,
              'feature_display_name' => 'h+ ssm4-D4',
              'taxonid' => undef,
              'with_or_from_identifier' => undef,
              'creation_date_short' => '20100102',
              'annotation_type' => 'phenotype',
              'conditions' => [],
              'submitter_comment' => undef,
              'feature_type' => 'genotype',
              'genotype_name' => undef,
              'annotation_id' => 7,
              'term_name' => 'elongated cells',
              'annotation_extension' => '',
              'feature_id' => 2,
              'completed' => 1,
              'status' => 'new',
              'publication_uniquename' => 'PMID:19756689',
              'genotype_identifier' => 'h+ ssm4-D4',
              'is_not' => 0,
              'annotation_type_display_name' => 'phenotype',
              'genotype_id' => 2
            },
            {
              'evidence_code' => 'UNK',
              'term_ontid' => 'FYPO:0000104',
              'gene_identifier' => 'SPBC12C2.02c',
              'qualifiers' => '',
              'gene_product' => '',
              'annotation_id' => 3,
              'with_or_from_display_name' => undef,
              'gene_name_or_identifier' => 'ste20',
              'gene_name' => 'ste20',
              'term_name' => 'sensitive to cycloheximide',
              'status' => 'existing',
              'allele_display_name' => 'ste20delta(del_x1)',
              'taxonid' => '4896',
              'with_or_from_identifier' => undef,
              'conditions' => [],
              'is_not' => 0,
              'annotation_type' => 'fission_yeast_phenotype'
            },
            {
              'qualifiers' => '',
              'curator' => 'Another Testperson <a.n.other.testperson@pombase.org>',
              'creation_date' => '2010-01-02',
              'is_obsolete_term' => 0,
              'term_ontid' => 'MOD:01157',
              'annotation_type_abbreviation' => '',
              'evidence_code' => 'ISS',
              'term_suggestion' => undef,
              'needs_with' => '1',
              'with_gene_id' => undef,
              'with_or_from_display_name' => undef,
              'gene_product' => 'TAP42 family protein involved in TOR signalling (predicted)',
              'taxonid' => 4896,
              'gene_id' => 4,
              'feature_display_name' => 'SPCC63.05',
              'gene_name_or_identifier' => 'SPCC63.05',
              'annotation_type' => 'post_translational_modification',
              'with_or_from_identifier' => undef,
              'creation_date_short' => '20100102',
              'submitter_comment' => undef,
              'gene_identifier' => 'SPCC63.05',
              'annotation_id' => 8,
              'feature_type' => 'gene',
              'status' => 'new',
              'term_name' => 'protein modification categorized by amino acid modified',
              'feature_id' => 4,
              'gene_name' => '',
              'annotation_extension' => '',
              'completed' => '',
              'is_not' => 0,
              'annotation_type_display_name' => 'protein modification',
              'gene_synonyms_string' => '',
              'publication_uniquename' => 'PMID:19756689'
            },
            {
              'status' => 'new',
              'gene_id' => 4,
              'feature_display_name' => 'SPCC63.05',
              'feature_id' => 4,
              'completed' => 1,
              'gene_display_name' => 'SPCC63.05',
              'is_inferred_annotation' => 0,
              'annotation_type' => 'genetic_interaction',
              'interacting_gene_id' => 3,
              'publication_uniquename' => 'PMID:19756689',
              'phenotypes' => '',
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'submitter_comment' => '',
              'interacting_gene_display_name' => 'doa10',
              'gene_identifier' => 'SPCC63.05',
              'interacting_gene_taxonid' => 4896,
              'interacting_gene_identifier' => 'SPBC14F5.07',
              'evidence_code' => 'Synthetic Haploinsufficiency',
              'score' => '',
              'annotation_id' => 4,
              'gene_taxonid' => 4896
            },
            {
              'gene_identifier' => 'SPCC63.05',
              'curator' => 'Some Testperson <some.testperson@pombase.org>',
              'submitter_comment' => '',
              'interacting_gene_display_name' => 'doa10',
              'evidence_code' => 'Far Western',
              'interacting_gene_taxonid' => 4896,
              'interacting_gene_identifier' => 'SPBC14F5.07',
              'annotation_id' => 5,
              'score' => '',
              'gene_taxonid' => 4896,
              'gene_id' => 4,
              'status' => 'new',
              'feature_id' => 4,
              'feature_display_name' => 'SPCC63.05',
              'gene_display_name' => 'SPCC63.05',
              'completed' => 1,
              'interacting_gene_id' => 3,
              'is_inferred_annotation' => 0,
              'annotation_type' => 'genetic_interaction',
              'publication_uniquename' => 'PMID:19756689',
              'phenotypes' => ''
            },
            {
              'publication_uniquename' => 'PMID:19756689',
              'gene_taxonid' => '4896',
              'interacting_gene_identifier' => 'SPCC1739.11c',
              'interacting_gene_taxonid' => '4896',
              'gene_display_name' => 'ste20',
              'evidence_code' => 'Phenotypic Enhancement',
              'interacting_gene_display_name' => 'cdc11',
              'status' => 'existing',
              'gene_identifier' => 'SPBC12C2.02c'
            },
            {
              'publication_uniquename' => 'PMID:19756689',
              'gene_taxonid' => '4896',
              'interacting_gene_taxonid' => '4896',
              'interacting_gene_identifier' => 'SPCC16A11.14',
              'evidence_code' => undef,
              'gene_display_name' => 'ste20',
              'status' => 'existing',
              'interacting_gene_display_name' => 'sfh1',
              'gene_identifier' => 'SPBC12C2.02c'
            }
          ]);
