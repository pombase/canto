use strict;
use warnings;
use Test::More tests => 90;
use Test::Deep;
use JSON;

use Capture::Tiny 'capture_stderr';

use Canto::TestUtil;
use Canto::Track;
use Canto::Curs::ServiceUtils;
use Canto::Track::OrganismLookup;

use Clone::PP qw(clone);


my $test_util = Canto::TestUtil->new();
my $track_schema = $test_util->track_schema();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $curs_key = 'aaaa0007';
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

$config->{implementation_classes}->{allele_adaptor} =
  'Canto::Chado::AlleleLookup';
$config->{implementation_classes}->{genotype_adaptor} =
  'Canto::Chado::GenotypeLookup';

my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $curs_schema,
                                                   config => $config);

my $res = $service_utils->list_for_service('genotype', 'curs_only');

cmp_deeply($res,
           [
            {
              'identifier' => 'aaaa0007-genotype-test-1',
              'name' => 'SPCC63.05delta ssm4KE',
              background => 'h+',
              comment => undef,
              display_name => 'SPCC63.05delta ssm4KE',
              genotype_id => 1,
              allele_string => 'SPCC63.05delta ssm4delta',
              annotation_count => 1,
              metagenotype_count_by_type => {
                interaction => 1,
              },
              strain_name => undef,
              'organism' => {
                              scientific_name => 'Schizosaccharomyces pombe',
                              'taxonid' => '4896',
                              'pathogen_or_host' => 'unknown',
                              'full_name' => 'Schizosaccharomyces pombe',
                              'common_name' => 'fission yeast'
                            },
            },
            {
              'identifier' => 'aaaa0007-genotype-test-2',
              'name' => undef,
              background => undef,
              comment => undef,
              display_name => 'ssm4-D4(del_100-200)[Knockdown]',
              genotype_id => 2,
              allele_string => 'ssm4-D4(del_100-200)[Knockdown]',
              annotation_count => 1,
              metagenotype_count_by_type => {
                interaction => 1,
              },
              strain_name => undef,
              'organism' => {
                              scientific_name => 'Schizosaccharomyces pombe',
                              'taxonid' => '4896',
                              'pathogen_or_host' => 'unknown',
                              'full_name' => 'Schizosaccharomyces pombe',
                              'common_name' => 'fission yeast'
                            },
            }
          ]);

my $spcc63_05 =
  $curs_schema->resultset('Gene')
    ->find({ primary_identifier => 'SPCC63.05' });

$res = $service_utils->list_for_service('genotype', 'all',
                                        {
                                          filter =>
                                            { gene_identifiers =>
                                                [
                                                  $spcc63_05->primary_identifier()
                                                ]
                                              }
                                          });


cmp_deeply($res,
           [
            {
              identifier => 'aaaa0007-genotype-test-1',
              name => 'SPCC63.05delta ssm4KE',
              background => 'h+',
              comment => undef,
              display_name => 'SPCC63.05delta ssm4KE',
              genotype_id => 1,
              allele_string => 'SPCC63.05delta ssm4delta',
              annotation_count => 1,
              metagenotype_count_by_type => {
                interaction => 1,
              },
              strain_name => undef,
              organism => {
                scientific_name => 'Schizosaccharomyces pombe',
                taxonid => '4896',
                pathogen_or_host => 'unknown',
                full_name => 'Schizosaccharomyces pombe',
                common_name => 'fission yeast'
              },
            },
          ]);

$res = $service_utils->list_for_service('genotype', 'all',
                                        {
                                          max => 10,
                                          filter =>
                                            { gene_identifiers =>
                                                [
                                                  'SPBC1826.01c', 'SPCC1739.11c'
                                                ]
                                              }
                                          });

cmp_deeply($res,
           [
             {
              'name' => 'cdc11-33 mot1-a1',
              'identifier' => 'aaaa0007-test-genotype-2',
              'allele_string' => 'cdc11-33 mot1-a1',
              'display_name' => 'cdc11-33 mot1-a1',
              'allele_identifiers' => ['SPCC1739.11c:allele-1','SPBC1826.01c:allele-1'],
              annotation_count => 0,
              organism => {
                scientific_name => 'Schizosaccharomyces pombe',
                taxonid => '4896',
                pathogen_or_host => 'unknown',
                full_name => 'Schizosaccharomyces pombe',
                common_name => 'pombe'
              },
            },
          ]);

$res = $service_utils->list_for_service('genotype', 'all',
                                        {
                                          max => 10,
                                          filter =>
                                            { gene_identifiers =>
                                                [
                                                  'SPAC27D7.13c'
                                                ]
                                              }
                                          });

cmp_deeply($res,
          [
            {
              'name' => 'SPCC63.05delta ssm4KE',
              background => 'h+',
              comment => undef,
              'allele_string' => 'SPCC63.05delta ssm4delta',
              'genotype_id' => 1,
              'display_name' => 'SPCC63.05delta ssm4KE',
              'identifier' => 'aaaa0007-genotype-test-1',
              annotation_count => 1,
              metagenotype_count_by_type => {
                interaction => 1,
              },
              strain_name => undef,
              organism => {
                scientific_name => 'Schizosaccharomyces pombe',
                taxonid => '4896',
                pathogen_or_host => 'unknown',
                full_name => 'Schizosaccharomyces pombe',
                common_name => 'fission yeast'
              },
            },
            {
              'name' => undef,
              background => undef,
              comment => undef,
              'allele_string' => 'ssm4-D4(del_100-200)[Knockdown]',
              'display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
              'genotype_id' => 2,
              'identifier' => 'aaaa0007-genotype-test-2',
              annotation_count => 1,
              metagenotype_count_by_type => {
                interaction => 1,
              },
              strain_name => undef,
              organism => {
                scientific_name => 'Schizosaccharomyces pombe',
                taxonid => '4896',
                pathogen_or_host => 'unknown',
                full_name => 'Schizosaccharomyces pombe',
                common_name => 'fission yeast'
              },
            },
            {
              'name' => 'cdc11-33 ssm4delta',
              'display_name' => 'cdc11-33 ssm4delta',
              'identifier' => 'aaaa0007-test-genotype-3',
              'allele_string' => 'cdc11-33 ssm4delta',
              'allele_identifiers' => [
                                        'SPCC1739.11c:allele-1',
                                        'SPAC27D7.13c:allele-1'
                                      ],
              annotation_count => 1,
              organism => {
                scientific_name => 'Schizosaccharomyces pombe',
                taxonid => '4896',
                pathogen_or_host => 'unknown',
                full_name => 'Schizosaccharomyces pombe',
                common_name => 'pombe'
              },
            }
          ]);


# find genotypes in Chado only
$res = $service_utils->list_for_service('genotype', 'external_only',
                                        {
                                          max => 10,
                                          filter =>
                                            { gene_identifiers =>
                                                [
                                                  'SPAC27D7.13c'
                                                ]
                                              }
                                          });

cmp_deeply($res,
           [
            {
              'allele_identifiers' => [
                                        'SPCC1739.11c:allele-1',
                                        'SPAC27D7.13c:allele-1'
                                      ],
              'name' => 'cdc11-33 ssm4delta',
              'allele_string' => 'cdc11-33 ssm4delta',
              'identifier' => 'aaaa0007-test-genotype-3',
              'display_name' => 'cdc11-33 ssm4delta',
              annotation_count => 1,
              organism => {
                scientific_name => 'Schizosaccharomyces pombe',
                taxonid => '4896',
                pathogen_or_host => 'unknown',
                full_name => 'Schizosaccharomyces pombe',
                common_name => 'pombe'
              },
            }
          ]);



# test gene list service

$res = $service_utils->list_for_service('gene');

my $expected_organism = {
  full_name => 'Schizosaccharomyces pombe',
  taxonid => 4896,
  pathogen_or_host => 'unknown',
};

cmp_deeply($res,
           [
            {
              'primary_name' => 'doa10',
              'primary_identifier' => 'SPBC14F5.07',
              display_name => 'doa10',
               gene_id => 3,
               feature_id => 3,
              organism => $expected_organism,
            },
            {
              'primary_identifier' => 'SPBC1826.01c',
              'primary_name' => 'mot1',
              display_name => 'mot1',
               gene_id => 1,
              feature_id => 1,
              organism => $expected_organism,
            },
            {
              'primary_name' => 'ssm4',
              'primary_identifier' => 'SPAC27D7.13c',
              display_name => 'ssm4',
               gene_id => 2,
              feature_id => 2,
              organism => $expected_organism,
            },
            {
              'primary_identifier' => 'SPCC63.05',
              'primary_name' => undef,
              display_name => 'SPCC63.05',
               gene_id => 4,
              feature_id => 4,
              organism => $expected_organism,
            },
          ]);

my $gene_identifier = 'SPBC14F5.07';
my $genotype_identifier = 'aaaa0007-genotype-test-1';

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
                                         $changes);

is ($res->{status}, 'success');
is ($res->{annotation}->{term_ontid}, 'FYPO:0000013');
is ($res->{annotation}->{genotype_identifier}, $genotype_identifier);
is ($res->{annotation}->{submitter_comment}, $new_comment);

# re-query
$first_genotype_annotation = $first_genotype->annotations()->first();

is ($first_genotype_annotation->data()->{submitter_comment}, $new_comment);


# test change a term
$res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                         {
                                           key => $curs_key,
                                           term_ontid => 'FYPO:0000133'
                                         });
is ($res->{status}, 'success');
# re-query
$first_genotype_annotation = $first_genotype->annotations()->first();
is ($first_genotype_annotation->data()->{term_ontid}, "FYPO:0000133");
is ($res->{annotation}->{term_ontid}, 'FYPO:0000133');
is ($res->{annotation}->{term_name}, 'elongated multinucleate cell');


# test setting evidence_code
$res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                         {
                                           key => $curs_key,
                                           evidence_code => "Cell growth assay",
                                         });
is ($res->{status}, 'success');
# re-query
$first_genotype_annotation = $first_genotype->annotations()->first();
is ($first_genotype_annotation->data()->{evidence_code}, "Cell growth assay");
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
                                         {
                                           key => $curs_key,
                                           conditions => $new_conditions,
                                         });
is ($res->{status}, 'success');
# re-query
$first_genotype_annotation = $first_genotype->annotations()->first();
my @res_conditions = @{$first_genotype_annotation->data()->{conditions}};

cmp_deeply(\@res_conditions, ['FYECO:0000006', 'some free text cond']);


# test illegal evidence_code
my $stderr = capture_stderr {
  $res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                           {
                                             key => $curs_key,
                                             evidence_code => "illegal",
                                           });
};

is ($res->{status}, 'error');
my $illegal_ev_code_message = 'no such evidence code: illegal';
is ($res->{message}, $illegal_ev_code_message);

# test illegal curs_key
$stderr = capture_stderr {
  $res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                           {
                                             key => 'illegal',
                                             evidence_code => "Cell growth assay",
                                           });
};
is ($res->{status}, 'error');
is ($res->{message}, 'incorrect key');


# test illegal field type
$stderr = capture_stderr {
  $res = $service_utils->change_annotation($first_genotype_annotation->annotation_id(),
                                           {
                                             key => $curs_key,
                                             illegal => "something",
                                           });
};
is ($res->{status}, 'error');
my $illegal_field_message = 'No such annotation field type: illegal';
is ($res->{message}, $illegal_field_message);


# test setting with_gene/with_or_from_identifier for a gene
$res = $service_utils->change_annotation($first_gene_annotation->annotation_id(),
                                         {
                                           key => $curs_key,
                                           submitter_comment => 'a short comment',
                                           with_gene_id => $c2d7_gene->gene_id(),
                                         });
is ($res->{status}, 'success');
is ($res->{annotation}->{with_or_from_identifier}, $c2d7_gene->primary_identifier());
is ($res->{annotation}->{submitter_comment}, 'a short comment');

# re-query
$first_gene_annotation->discard_changes();
is ($first_gene_annotation->data()->{evidence_code}, "IPI");
is ($first_gene_annotation->data()->{with_gene}, $c2d7_gene->primary_identifier());
is ($first_gene_annotation->data()->{submitter_comment}, 'a short comment');


# test setting to a term from a different ontology
# biological_process -> molecular_function
$res = $service_utils->change_annotation($first_gene_annotation->annotation_id(),
                                         {
                                           key => $curs_key,
                                           term_ontid => 'GO:0004156',
                                         });
is ($res->{status}, 'success');
is ($res->{annotation}->{term_ontid}, 'GO:0004156');
# annotation type should change:
is ($res->{annotation}->{annotation_type}, 'molecular_function');

# re-query
$first_gene_annotation->discard_changes();
is ($first_gene_annotation->type(), 'molecular_function');



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
is ($res->{annotation}->{curator}, 'Some Testperson <some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org>');

is ($c2d7_gene->direct_annotations()->count(), 2);

my $new_annotation_id = $res->{annotation}->{annotation_id};

my $new_annotation = $curs_schema->find_with_type('Annotation', $new_annotation_id);
is ($new_annotation->data()->{term_ontid}, 'GO:0022857');


# test lack of information
$stderr = capture_stderr {
  $res = $service_utils->create_annotation({
    key => $curs_key,
  });
};
is ($res->{status}, 'error');
my $lack_of_info_message = 'No feature(s) passed to annotation creation service';
is ($res->{message}, $lack_of_info_message);


# delete
$res = $service_utils->delete_annotation({
                                           key => $curs_key,
                                           annotation_id => $new_annotation_id,
                                         });

is ($c2d7_gene->direct_annotations()->count(), 1);
is ($curs_schema->resultset('Annotation')->search({ annotation_id => $new_annotation_id })->count(), 0);


# test interaction annotation services

my $genotype_interaction_annotation =
  $curs_schema->resultset('Annotation')->find({ type => 'genotype_interaction',
                                                data => { -like => '%Synthetic Haploinsufficiency%' } });


# test illegal field type
$stderr = capture_stderr {
  $res = $service_utils->change_annotation($genotype_interaction_annotation->annotation_id(),
                                           {
                                             key => $curs_key,
                                             illegal => "something",
                                           });
};
is ($res->{status}, 'error');
my $illegal_field_type_message = 'No such annotation field type: illegal';
is ($res->{message}, $illegal_field_type_message);


my $metagenotype_rs = $curs_schema->resultset('Metagenotype')->search();

my $test_metagenotype = $metagenotype_rs->first();

# test editing
$res = $service_utils->change_annotation($genotype_interaction_annotation->annotation_id(),
                                         {
                                           key => $curs_key,
                                           feature_id => $test_metagenotype->metagenotype_id(),
                                           feature_type => 'metagenotype',
                                         });

is ($res->{status}, 'success');
cmp_deeply ($res->{annotation},
            {
              'publication_uniquename' => 'PMID:19756689',
              'score' => '',
              'annotation_id' => $genotype_interaction_annotation->annotation_id(),
              'curator' => 'Some Testperson <some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org>',
              'genotype_a_display_name' => 'SPCC63.05delta ssm4KE',
              'genotype_a_id' => 1,
              'genotype_a_taxonid' => 4896,
              'genotype_a_gene_ids' => [2, 4],
              'feature_a_display_name' => 'SPCC63.05delta ssm4KE',
              'feature_a_id' => 1,
              'feature_a_taxonid' => 4896,
              'genotype_b_display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
              'genotype_b_id' => 2,
              'genotype_b_taxonid' => 4896,
              'feature_b_display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
              'feature_b_id' => 2,
              'feature_b_taxonid' => 4896,
              'genotype_b_gene_ids' => [2],
              'organism' => {
                taxonid => '4896',
                scientific_name => 'Schizosaccharomyces pombe',
                full_name => 'Schizosaccharomyces pombe',
                common_name => 'fission yeast',
                pathogen_or_host => 'unknown',
              },
              'term_ontid' => 'FYPO:0000114',
              'term_name' => 'cellular process phenotype',
              'extension' => [],
              'conditions' => [{
                                'name' => 'glucose rich medium',
                                'term_id' => 'FYECO:0000137'
                              }],
              'is_inferred_annotation' => 0,
              'evidence_code' => 'Synthetic Haploinsufficiency',
              'status' => 'new',
              'completed' => 1,
              'submitter_comment' => '',
              'figure' => '',
              'is_obsolete_term' => 0,
              'annotation_type' => 'genotype_interaction',
              'annotation_type_display_name' => 'genetic interaction',
              'checked' => 'no',
            }
          );


# test condition list service
my $cond_res = $service_utils->list_for_service('condition');

cmp_deeply($cond_res,
           [
             {
               'name' => 'glucose rich medium',
               'term_id' => 'FYECO:0000137'
             },
             {
               'term_id' => 'FYECO:0000006',
               'name' => 'low temperature'
             },
             {
               'name' => 'some free text cond'
             }
           ]);

# test annotation list service
my $annotation_res = $service_utils->list_for_service('annotation');

my $cycloheximide_annotation_res = $Canto::TestUtil::shared_test_results{cycloheximide_annotation};
my $post_translational_modification_res = $Canto::TestUtil::shared_test_results{post_translational_modification};

sub clean_results
{
  my $annotation_res = shift;
  map {
    delete $_->{checked};
  } @$annotation_res;
}

clean_results($annotation_res);

my $annotation_expected_organism = {
  full_name => 'Schizosaccharomyces pombe',
  common_name => 'fission yeast',
  pathogen_or_host => 'unknown',
  taxonid => '4896',
  scientific_name => 'Schizosaccharomyces pombe'
};

cmp_deeply($annotation_res,
         [
            {
              'annotation_id' => 2,
              'extension' => [
                [
                  {
                    relation => 'exists_during',
                    rangeType => 'Ontology',
                    rangeValue => 'GO:0051329',
                  },
                  {
                    relation => 'has_substrate',
                    rangeType => 'Gene',
                    rangeValue => 'PomBase:SPBC1105.11c',
                  },
                  {
                    relation => 'requires_feature',
                    rangeType => 'Gene',
                    rangeValue => 'Pfam:PF00564',
                  },
                ],
                [
                  {
                    relation => 'exists_during',
                    rangeType => 'Ontology',
                    rangeValue => 'GO:0051329',
                  },
                  {
                    relation => 'has_substrate',
                    rangeType => 'Gene',
                    rangeValue => 'PomBase:SPBC1105.11c',
                  }
                ],
              ],
              'gene_product' => 'ER-localized ubiquitin ligase Doa10 (predicted)',
              'annotation_type' => 'molecular_function',
              'status' => 'new',
              'publication_uniquename' => 'PMID:19756689',
              'feature_id' => 3,
              'qualifiers' => [],
              'with_or_from_identifier' => 'SPAC27D7.13c',
              'curator' => 'Some Testperson <some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org>',
              'needs_with' => '1',
              'gene_name_or_identifier' => 'doa10',
              'is_obsolete_term' => 0,
              'term_suggestion_name' => undef,
              'term_suggestion_definition' => undef,
              'annotation_type_abbreviation' => 'F',
              'gene_synonyms_string' => 'ssm4',
              'term_name' => 'dihydropteroate synthase activity',
              'gene_id' => 3,
              'term_ontid' => 'GO:0004156',
              'feature_display_name' => 'doa10',
              'feature_type' => 'gene',
              'annotation_type_display_name' => 'GO molecular function',
              'creation_date_short' => '20100102',
              'completed' => 1,
              'taxonid' => 4896,
              'organism' => $annotation_expected_organism,
              'is_not' => JSON::false,
              'creation_date' => '2010-01-02',
              'evidence_code' => 'IPI',
              'submitter_comment' => 'a short comment',
              'figure' => undef,
              'with_or_from_display_name' => 'ssm4',
              'gene_name' => 'doa10',
              'gene_identifier' => 'SPBC14F5.07',
              'with_gene_id' => 2,
            },
            {
              'evidence_code' => 'IDA',
              'creation_date' => '2010-01-02',
              'with_gene_id' => undef,
              'gene_identifier' => 'SPBC14F5.07',
              'gene_name' => 'doa10',
              'with_or_from_display_name' => undef,
              'submitter_comment' => undef,
              'figure' => undef,
              'feature_type' => 'gene',
              'feature_display_name' => 'doa10',
              'term_ontid' => 'GO:0022857',
              'gene_id' => 3,
              'gene_synonyms_string' => 'ssm4',
              'term_name' => 'transmembrane transporter activity',
              'is_not' => JSON::false,
              'taxonid' => 4896,
              'organism' => $annotation_expected_organism,
              'creation_date_short' => '20100102',
              'completed' => 1,
              'annotation_type_display_name' => 'GO molecular function',
              'needs_with' => undef,
              'annotation_type_abbreviation' => 'F',
              'term_suggestion_name' => undef,
              'term_suggestion_definition' => undef,
              'is_obsolete_term' => 0,
              'gene_name_or_identifier' => 'doa10',
              'feature_id' => 3,
              'publication_uniquename' => 'PMID:19756689',
              'gene_product' => 'ER-localized ubiquitin ligase Doa10 (predicted)',
              'extension' => [],
              'annotation_type' => 'molecular_function',
              'status' => 'new',
              'annotation_id' => 3,
              'curator' => 'Some Testperson <some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org>',
              'with_or_from_identifier' => undef,
              'with_gene_id' => undef,
              'qualifiers' => [],
            },
            {
              'submitter_comment' => undef,
              'figure' => undef,
              'gene_name' => 'ssm4',
              'with_or_from_display_name' => undef,
              'with_gene_id' => undef,
              'gene_identifier' => 'SPAC27D7.13c',
              'creation_date' => '2010-01-02',
              'evidence_code' => 'IMP',
              'annotation_type_display_name' => 'GO biological process',
              'taxonid' => 4896,
              'organism' => $annotation_expected_organism,
              'completed' => 1,
              'creation_date_short' => '20100102',
              'is_not' => JSON::false,
              'gene_synonyms_string' => 'SPAC637.01c',
              'term_name' => 'transmembrane transport',
              'term_ontid' => 'GO:0055085',
              'gene_id' => 2,
              'feature_display_name' => 'ssm4',
              'feature_type' => 'gene',
              'gene_name_or_identifier' => 'ssm4',
              'is_obsolete_term' => 0,
              'term_suggestion_name' => 'miscellaneous transmembrane transport',
              'term_suggestion_definition' => 'The process in which miscellaneous stuff is transported from one side of a membrane to the other.',
              'annotation_type_abbreviation' => 'P',
              'needs_with' => undef,
              'qualifiers' => [],
              'with_or_from_identifier' => undef,
              'curator' => 'Some Testperson <some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org>',
              'extension' => [],
              'annotation_type' => 'biological_process',
              'gene_product' => 'p150-Glued',
              'status' => 'new',
              'annotation_id' => 1,
              'feature_id' => 2,
              'publication_uniquename' => 'PMID:19756689',
            },
            {
              'evidence_code' => 'UNK',
              'gene_name_or_identifier' => 'ste20',
              'with_or_from_display_name' => undef,
              'gene_name' => 'ste20',
              'gene_id' => undef,
              'feature_id' => undef,
              'conditions' => [],
              'gene_identifier' => 'SPBC12C2.02c',
              'gene_product_form_id' => undef,
              'term_name' => 'transport',
              'term_ontid' => 'GO:0006810',
              'annotation_id' => 2,
              'annotation_type' => 'biological_process',
              'status' => 'existing',
              'feature_display_name' => 'ste20',
              'gene_product' => '',
              'feature_type' => 'gene',
              'qualifiers' => [],
              'with_or_from_identifier' => undef,
              'with_gene_id' => undef,
              'taxonid' => '4896',
              'is_not' => JSON::true,
              'extension' =>
                [
                  [
                    {
                      'relation' => 'requires_direct_regulator',
                      'rangeValue' => 'CONFIGURE_IN_CANTO_DEPLOY.YAML:cdc11'
                    }
                  ]
                ],
               'organism' => {
                 'pathogen_or_host' => 'unknown',
                 'full_name' => 'Schizosaccharomyces pombe',
                 'taxonid' => '4896',
                 'common_name' => 'fission yeast',
                 'scientific_name' => 'Schizosaccharomyces pombe',
               },
            },
            {
              'evidence_code' => 'IMP',
              'gene_name' => 'ste20',
              'gene_id' => undef,
              'feature_id' => undef,
              'with_or_from_display_name' => 'PomBase:SPBC2G2.01c',
              'gene_name_or_identifier' => 'ste20',
              'gene_product_form_id' => 'PR:000027576',
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
              'qualifiers' => [],
              'is_not' => JSON::false,
              'with_or_from_identifier' => 'PomBase:SPBC2G2.01c',
              'with_gene_id' => undef,
              'taxonid' => '4896',
              'extension' => undef,
              'organism' => {
                'pathogen_or_host' => 'unknown',
                'full_name' => 'Schizosaccharomyces pombe',
                'taxonid' => '4896',
                'common_name' => 'fission yeast',
                'scientific_name' => 'Schizosaccharomyces pombe',
              },
            },
            {
              'term_ontid' => 'FYPO:0000133',
              'term_name' => 'elongated multinucleate cell',
              'feature_type' => 'genotype',
              'feature_display_name' => 'SPCC63.05delta ssm4KE',
              'annotation_type_display_name' => 'phenotype',
              'is_not' => JSON::false,
              'completed' => 1,
              'creation_date_short' => '20100102',
              'taxonid' => undef,
              'creation_date' => '2010-01-02',
              'evidence_code' => 'Cell growth assay',
              'genotype_id' => 1,
              'with_or_from_display_name' => undef,
              'genotype_display_name' => 'SPCC63.05delta ssm4KE',
              'submitter_comment' => 'new service comment',
              'figure' => undef,
              'with_gene_id' => undef,
              'conditions' => [
                                {
                                  'name' => 'low temperature',
                                  'term_id' => 'FYECO:0000006'
                                },
                                {
                                  'name' => 'some free text cond'
                                }
                              ],
              'publication_uniquename' => 'PMID:19756689',
              'feature_id' => 1,
              'annotation_id' => 6,
              'extension' => [],
              'annotation_type' => 'phenotype',
              'status' => 'new',
              'qualifiers' => [],
              'curator' => 'Some Testperson <some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org>',
              'with_or_from_identifier' => undef,
              'needs_with' => undef,
              'genotype_name' => 'SPCC63.05delta ssm4KE',
              'genotype_background' => 'h+',
              'term_suggestion_name' => undef,
              'term_suggestion_definition' => undef,
              'is_obsolete_term' => 0,
              'genotype_identifier' => 'aaaa0007-genotype-test-1',
              'organism' => {
                'pathogen_or_host' => 'unknown',
                'common_name' => 'fission yeast',
                'scientific_name' => 'Schizosaccharomyces pombe',
                'full_name' => 'Schizosaccharomyces pombe',
                'taxonid' => '4896',
              },
              'strain_name' => undef,
              'annotation_type_abbreviation' => '',
              'alleles' => [
                {
                  'gene_id' => 2,
                  'allele_id' => 1,
                  'expression' => undef,
                  'primary_identifier' => 'SPAC27D7.13c:aaaa0007-1',
                  'name' => 'ssm4delta',
                  'description' => 'deletion',
                  'type' => 'deletion',
                  'display_name' => 'ssm4delta',
                  'long_display_name' => 'ssm4delta',
                  'gene_display_name' => 'ssm4',
                  'synonyms' => [],
                },
                {
                  'description' => 'deletion',
                  'type' => 'deletion',
                  'expression' => undef,
                  'gene_id' => 4,
                  'allele_id' => 5,
                  'name' => 'SPCC63.05delta',
                  'primary_identifier' => 'SPCC63.05:aaaa0007-1',
                  'display_name' => 'SPCC63.05delta',
                  'long_display_name' => 'SPCC63.05delta',
                  'gene_display_name' => 'SPCC63.05',
                  'synonyms' => [],
                }
              ],
            },
            {
              'evidence_code' => 'Co-immunoprecipitation experiment',
              'genotype_id' => 2,
              'creation_date' => '2010-01-02',
              'with_gene_id' => undef,
              'conditions' => [],
              'with_or_from_display_name' => undef,
              'genotype_display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
              'submitter_comment' => undef,
              'figure' => undef,
              'feature_type' => 'genotype',
              'feature_display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
              'term_ontid' => 'FYPO:0000017',
              'term_name' => 'elongated cell',
              'is_not' => JSON::false,
              'completed' => 1,
              'creation_date_short' => '20100102',
              'taxonid' => undef,
              'annotation_type_display_name' => 'phenotype',
              'needs_with' => undef,
              'genotype_identifier' => 'aaaa0007-genotype-test-2',
              'organism' => {
                'pathogen_or_host' => 'unknown',
                'common_name' => 'fission yeast',
                'scientific_name' => 'Schizosaccharomyces pombe',
                'full_name' => 'Schizosaccharomyces pombe',
                'taxonid' => '4896',
              },
              'strain_name' => undef,
              'annotation_type_abbreviation' => '',
              'genotype_name' => undef,
              'genotype_background' => undef,
              'term_suggestion_name' => undef,
              'term_suggestion_definition' => undef,
              'is_obsolete_term' => 0,
              'publication_uniquename' => 'PMID:19756689',
              'feature_id' => 2,
              'annotation_id' => 7,
              'annotation_type' => 'phenotype',
              'extension' => [],
              'status' => 'new',
              'curator' => 'Some Testperson <some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org>',
              'with_or_from_identifier' => undef,
              'qualifiers' => [],
              'alleles' => [
                {
                  'name' => 'ssm4-D4',
                  'gene_id' => 2,
                  'expression' => 'Knockdown',
                  'description' => 'del_100-200',
                  'primary_identifier' => 'SPAC27D7.13c:aaaa0007-3',
                  'allele_id' => 3,
                  'type' => 'partial deletion, nucleotide',
                  'display_name' => 'ssm4-D4(del_100-200)',
                  'long_display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
                  'gene_display_name' => 'ssm4',
                  'synonyms' => [{ edit_status => 'new', synonym => 'ssm4-c1' }],
                }
              ],
            },
            $cycloheximide_annotation_res,
            $post_translational_modification_res,
            {
              'genotype_a_display_name' => 'SPCC63.05delta ssm4KE',
              'genotype_a_id' => 1,
              'genotype_a_taxonid' => 4896,
              'feature_a_display_name' => 'SPCC63.05delta ssm4KE',
              'feature_a_id' => 1,
              'feature_a_taxonid' => 4896,
              'genotype_a_gene_ids' => [2, 4],
              'genotype_b_display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
              'genotype_b_id' => 2,
              'genotype_b_taxonid' => 4896,
              'feature_b_display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
              'feature_b_id' => 2,
              'feature_b_taxonid' => 4896,
              'genotype_b_gene_ids' => [2],
              'organism' => {
                taxonid => '4896',
                scientific_name => 'Schizosaccharomyces pombe',
                full_name => 'Schizosaccharomyces pombe',
                common_name => 'fission yeast',
                pathogen_or_host => 'unknown',
              },
              'term_ontid' => 'FYPO:0000114',
              'term_name' => 'cellular process phenotype',
              'extension' => [],
              'conditions' => [{'name' => 'glucose rich medium', 'term_id' => 'FYECO:0000137'}],
              'evidence_code' => 'Synthetic Haploinsufficiency',
              'submitter_comment' => '',
              'figure' => '',
              'is_inferred_annotation' => 0,
              'publication_uniquename' => 'PMID:19756689',
              'score' => '',
              'annotation_id' => 4,
              'status' => 'new',
              'is_obsolete_term' => 0,
              'annotation_type' => 'genotype_interaction',
              'annotation_type_display_name' => 'genetic interaction',
              'curator' => 'Some Testperson <some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org>',
              'completed' => 1
            },
            {
              'evidence_code' => 'Phenotypic Enhancement',
              'publication_uniquename' => 'PMID:19756689',
              'status' => 'existing',
              'gene_display_name' => 'ste20',
              'gene_identifier' => 'SPBC12C2.02c',
              'feature_a_display_name' => 'ste20',
              'interacting_gene_display_name' => 'cdc11',
              'interacting_gene_identifier' => 'SPCC1739.11c',
              'interacting_gene_taxonid' => '4896',
              'interacting_gene_id' => undef,
              'feature_b_display_name' => 'cdc11',
              'annotation_type' => 'genetic_interaction',
              'gene_taxonid' => '4896',
              'gene_id' => undef,
            },
            {
              'gene_display_name' => 'ste20',
              'status' => 'existing',
              'evidence_code' => undef,
              'publication_uniquename' => 'PMID:19756689',
              'gene_taxonid' => '4896',
              'gene_id' => undef,
              'feature_a_display_name' => 'ste20',
              'interacting_gene_display_name' => 'sfh1',
              'interacting_gene_taxonid' => '4896',
              'interacting_gene_identifier' => 'SPCC16A11.14',
              'interacting_gene_id' => undef,
              'feature_b_display_name' => 'sfh1',
              'annotation_type' => 'genetic_interaction',
              'gene_identifier' => 'SPBC12C2.02c'
            },
            {
              'submitter_comment' => '',
              'figure' => '',
              'interacting_gene_id' => 2,
              'completed' => 1,
              'gene_display_name' => 'SPCC63.05',
              'gene_id' => 4,
              'gene_identifier' => 'SPCC63.05',
              'annotation_id' => 5,
              'feature_b_taxonid' => '4896',
              'interacting_gene_taxonid' => '4896',
              'feature_id' => 4,
              'annotation_type' => 'physical_interaction',
              'score' => '',
              'evidence_code' => 'Far Western',
              'feature_b_display_name' => 'ssm4',
              'is_inferred_annotation' => 0,
              'feature_a_id' => 4,
              'publication_uniquename' => 'PMID:19756689',
              'annotation_type_display_name' => 'physical interaction',
              'curator' => 'Some Testperson <some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org>',
              'feature_a_taxonid' => '4896',
              'gene_taxonid' => '4896',
              'feature_display_name' => 'SPCC63.05',
              'interacting_gene_identifier' => 'SPAC27D7.13c',
              'status' => 'new',
              'feature_a_display_name' => 'SPCC63.05',
              'feature_b_id' => 2,
              'interacting_gene_display_name' => 'ssm4',
              'phenotypes' => ''
            }
          ]);



$annotation_res = $service_utils->list_for_service('annotation', 'post_translational_modification');

clean_results($annotation_res);

cmp_deeply($annotation_res,
           [
             $post_translational_modification_res,
           ]);


# read from CursDB
my $allele_res = $service_utils->list_for_service('allele', 'SPAC27D7.13c', 'ssm');

cmp_deeply($allele_res,
           [
            {
              'uniquename' => 'SPAC27D7.13c:aaaa0007-1',
              'description' => 'deletion',
              'expression' => undef,
              'display_name' => 'ssm4delta',
              'long_display_name' => 'ssm4delta',
              'name' => 'ssm4delta',
              'type' => 'deletion',
              'allele_id' => 1,
              'comment' => undef,
              'gene_id' => 2,
              'gene_display_name' => 'ssm4',
              'gene_systematic_id' => 'SPAC27D7.13c',
              'synonyms' => [],
              'notes' => {},
            },
            {
              'allele_id' => 3,
              'gene_id' => 2,
              'description' => 'del_100-200',
              'uniquename' => 'SPAC27D7.13c:aaaa0007-3',
              'expression' => 'Knockdown',
              'display_name' => 'ssm4-D4(del_100-200)',
              'long_display_name' => 'ssm4-D4(del_100-200)[Knockdown]',
              'name' => 'ssm4-D4',
              'type' => 'partial deletion, nucleotide',
              'comment' => undef,
              'gene_display_name' => 'ssm4',
              'gene_systematic_id' => 'SPAC27D7.13c',
              'synonyms' => [{ edit_status => 'new', synonym => 'ssm4-c1' }],
              'notes' => {
                'note_test_key' => 'note_test_value',
              },
            },
            {
              'uniquename' => 'SPAC27D7.13c:allele-2',
              'type' => 'partial deletion, nucleotide',
              'display_name' => 'ssm4-L1(80-90)',
              'description' => '80-90',
              'name' => 'ssm4-L1',
              'synonyms' => [],
            },
          ]);

$allele_res = $service_utils->list_for_service('allele', 'SPBC12C2.02c', 'ste');

cmp_deeply($allele_res,
           $Canto::TestUtil::shared_test_results{allele}{ste});


my $expected_genotype_detail_res =
  {
    'name' => 'SPCC63.05delta ssm4KE',
    background => 'h+',
    comment => undef,
    'identifier' => 'aaaa0007-genotype-test-1',
    'allele_string' => 'SPCC63.05delta ssm4delta',
    'genotype_id' => 1,
    'locus_count' => 2,
    'diploid_locus_count' => 0,
    'display_name' => 'SPCC63.05delta ssm4KE',
    strain_name => undef,
    'alleles' => [
      {
        'allele_id' => 1,
        'description' => 'deletion',
        'display_name' => 'ssm4delta',
        'long_display_name' => 'ssm4delta',
        'expression' => undef,
        'gene_id' => 2,
        'name' => 'ssm4delta',
        'type' => 'deletion',
        'uniquename' => 'SPAC27D7.13c:aaaa0007-1',
        'gene_display_name' => 'ssm4',
        'gene_systematic_id' => 'SPAC27D7.13c',
        'synonyms' => [],
        'comment' => undef,
        'notes' => {},
     },
      {
        'allele_id' => 5,
        'description' => 'deletion',
        'display_name' => 'SPCC63.05delta',
        'long_display_name' => 'SPCC63.05delta',
        'expression' => undef,
        'gene_id' => 4,
        'name' => 'SPCC63.05delta',
        'type' => 'deletion',
        'uniquename' => 'SPCC63.05:aaaa0007-1',
        'gene_display_name' => 'SPCC63.05',
        'gene_systematic_id' => 'SPCC63.05',
        'synonyms' => [],
        'comment' => undef,
        'notes' => {},
      },
    ],
    annotation_count => 1,
    metagenotype_count_by_type => {
      interaction => 1,
    },
    organism => {
      scientific_name => 'Schizosaccharomyces pombe',
      taxonid => '4896',
      pathogen_or_host => 'unknown',
      full_name => 'Schizosaccharomyces pombe',
      common_name => 'fission yeast'
    },
  };

my $genotype_detail_res =
  $service_utils->details_for_service('genotype', 'by_id',
                                      $first_genotype->genotype_id());

cmp_deeply($genotype_detail_res,
           $expected_genotype_detail_res);

$genotype_detail_res =
  $service_utils->details_for_service('genotype', 'by_identifier',
                                      $first_genotype->identifier());

cmp_deeply($genotype_detail_res,
           $expected_genotype_detail_res);


# deletion
my $genotype_delete_res = $service_utils->delete_genotype($first_genotype->genotype_id());

# fails because no curs_key is passed
is ($genotype_delete_res->{status}, 'error');
is ($genotype_delete_res->{message}, 'incorrect key');

# fails because first_genotype has annotations
$genotype_delete_res = $service_utils->delete_genotype($first_genotype->genotype_id(), { key => 'aaaa0007' });
is ($genotype_delete_res->{status}, 'error');
is ($genotype_delete_res->{message}, 'genotype has annotations - delete failed');

my $second_genotype =
  $curs_schema->resultset('Genotype')->find({ identifier => 'aaaa0007-genotype-test-2' });

# remove the annotations so we can delete genotypes
$curs_schema->resultset('GenotypeAnnotation')->delete();

sub unused_alleles_count
{
  my $unused_alleles_rs =
    $curs_schema->resultset('Allele')
    ->search({},
             {
               where => \"allele_id NOT IN (SELECT allele FROM allele_genotype)",
             });
}

is (unused_alleles_count(), 2);

# clean test data
Canto::Track::validate_curs($config, $test_util->track_schema(),
                            $test_util->track_schema()->find_with_type('Curs', { curs_key => 'aaaa0007' }));

is (unused_alleles_count(), 0);

# delete the interaction metagenotype so we can test delete_genotype()
$curs_schema->resultset('MetagenotypeAnnotation')->delete();
$curs_schema->resultset('Metagenotype')->delete();

$genotype_delete_res = $service_utils->delete_genotype($second_genotype->genotype_id(), { key => 'aaaa0007' });

if ($genotype_delete_res->{status} ne 'success') {
  fail($genotype_delete_res->{status});
}

is (unused_alleles_count(), 0);


my $add_gene_result = $service_utils->add_gene_by_identifier('SPBC12C2.02c');

cmp_deeply($add_gene_result,
           {
             'gene_id' => 5,
             'status' => 'success'
           });

# if we try to add it a second time it won't be added and we'll get a
# "gene_id" of undef
$add_gene_result = $service_utils->add_gene_by_identifier('SPBC12C2.02c');

cmp_deeply($add_gene_result,
           {
             'gene_id' => undef,
             'status' => 'success'
           });

$stderr = capture_stderr {
  $add_gene_result = $service_utils->add_gene_by_identifier('dummy');
};

my $add_dummy_gene_message = qq(couldn\'t find gene "dummy");
cmp_deeply($add_gene_result,
           {
             'status' => 'error',
             'message' => $add_dummy_gene_message,
           });

# session details
my $session_detail_res =
  $service_utils->details_for_service('session');

cmp_deeply($session_detail_res,
           {
             publication_uniquename => 'PMID:19756689',
             curator => {
               'curator_name' => 'Some Testperson',
               'curator_known_as' => undef,
               'curator_email' => 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org',
               'community_curated' => JSON::true,
               'accepted_date' => '2012-02-15 13:45:00',
             },
             'state' => 'CURATION_IN_PROGRESS',
           });


# metagenotype list

# set pombe as a host organism in pathogen_host_mode
$config->{host_organism_taxonids} = [4932];
$config->_set_host_organisms($track_schema);
$Canto::Track::OrganismLookup::cache = {};

my $phi_phenotype_config = clone $config->{annotation_types}->{phenotype};
$phi_phenotype_config->{name} = 'disease_formation_phenotype';
$phi_phenotype_config->{namespace} = 'disease_formation_phenotype';
$phi_phenotype_config->{feature_type} = 'metagenotype';

push @{$config->{available_annotation_type_list}}, $phi_phenotype_config;
$config->{annotation_types}->{$phi_phenotype_config->{name}} = $phi_phenotype_config;


my $genotype_manager = Canto::Curs::GenotypeManager->new(config => $config,
                                                         curs_schema => $curs_schema);
my $existing_pombe_genotype =
  $curs_schema->find_with_type('Genotype', { identifier => 'aaaa0007-genotype-test-1' });

ok ($existing_pombe_genotype);

my $cerevisiae_genotype =
  $genotype_manager->make_genotype(undef, undef, [], 4932);

my $metagenotype =
  $genotype_manager->make_metagenotype(pathogen_genotype => $existing_pombe_genotype,
                                       host_genotype => $cerevisiae_genotype);

my $metagenotypes_list_res =
  $service_utils->list_for_service('metagenotype');

is (scalar(@{$metagenotypes_list_res}), 1);

is ($metagenotypes_list_res->[0]->{host_genotype}->{identifier}, 'aaaa0007-genotype-3');
is ($metagenotypes_list_res->[0]->{host_genotype}->{allele_string}, '');
is ($metagenotypes_list_res->[0]->{host_genotype}->{organism}->{scientific_name},
    'Saccharomyces cerevisiae');
is ($metagenotypes_list_res->[0]->{pathogen_genotype}->{identifier}, 'aaaa0007-genotype-test-1');
is ($metagenotypes_list_res->[0]->{pathogen_genotype}->{allele_string}, 'SPCC63.05delta ssm4delta');
is ($metagenotypes_list_res->[0]->{pathogen_genotype}->{organism}->{scientific_name},
    'Schizosaccharomyces pombe');


$metagenotypes_list_res =
  $service_utils->list_for_service('metagenotype', { pathogen_taxonid => 9954321 });

is (scalar(@{$metagenotypes_list_res}), 0);

$metagenotypes_list_res =
  $service_utils->list_for_service('metagenotype', { pathogen_taxonid => 4896 });

is (scalar(@{$metagenotypes_list_res}), 1);

$metagenotypes_list_res =
  $service_utils->list_for_service('metagenotype', { host_taxonid => 9954321 });

is (scalar(@{$metagenotypes_list_res}), 0);

$metagenotypes_list_res =
  $service_utils->list_for_service('metagenotype', { host_taxonid => 9954321, pathogen_taxonid => 4896 });

is (scalar(@{$metagenotypes_list_res}), 0);

$metagenotypes_list_res =
  $service_utils->list_for_service('metagenotype', { host_taxonid => 4932, pathogen_taxonid => 4896 });

is (scalar(@{$metagenotypes_list_res}), 1);


# strain lookup

$track_schema = $test_util->track_schema();
my $track_organism = $track_schema->resultset('Organism')->first();
my $track_strain_1 = $track_schema->resultset('Strain')
  ->create({ strain_name => 'track strain name 1', strain_id => 1001,
             organism_id => $track_organism->organism_id() });
$track_schema->resultset('Strainsynonym')
  ->create({ strain => $track_strain_1, synonym => 'track_strain_1_syn' });


my $curs_organism = $track_schema->resultset('Organism')->first();
$curs_schema->resultset('Strain')
  ->create({ strain_name => 'curs strain',
             organism_id => $curs_organism->organism_id() });
$curs_schema->resultset('Strain')
  ->create({ track_strain_id => 1001,
             organism_id => $curs_organism->organism_id() });

my $strain_res = $service_utils->list_for_service('strain');

is(@$strain_res, 2);

cmp_deeply($strain_res,
           [
             {
               'taxon_id' => 4896,
               'strain_name' => 'curs strain'
             },
             {
               'strain_id' => 1001,
               'taxon_id' => 4896,
               'strain_name' => 'track strain name 1',
               'synonyms' => ['track_strain_1_syn'],
             }
           ]);


$service_utils->delete_strain_by_id(1001);


$strain_res = $service_utils->list_for_service('strain');

is(@$strain_res, 1);

cmp_deeply($strain_res,
           [
             {
               'taxon_id' => 4896,
               'strain_name' => 'curs strain'
             },
           ]);

