use strict;
use warnings;
use Test::More tests => 117;
use Test::Deep;

use Canto::TestUtil;
use Canto::Curs::Utils;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $schema = $test_util->track_schema();

my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');
sub check_new_annotations
{
  my $exp_term_ontid = shift // 'GO:0055085';

  {
    my ($completed_count, $annotations_ref) =
      Canto::Curs::Utils::get_annotation_table($config, $curs_schema,
                                                'biological_process');

    my @annotations = @$annotations_ref;

    is (@annotations, 2);

    is ($annotations[0]->{gene_identifier}, 'SPAC27D7.13c');
    is ($annotations[0]->{term_ontid}, $exp_term_ontid);
    is ($annotations[0]->{taxonid}, '4896');
    like ($annotations[0]->{creation_date}, qr/\d+-\d+-\d+/);
    is ($annotations[0]->{gene_synonyms_string}, 'SPAC637.01c');
  }

  {
    my ($completed_count, $annotations_ref) =
      Canto::Curs::Utils::get_annotation_table($config, $curs_schema,
                                                'genetic_interaction');

    my @annotations = @$annotations_ref;

    is (@annotations, 2);

    my $interacting_gene_count = 0;

    for my $annotation (@annotations) {
      is ($annotation->{gene_identifier}, 'SPCC63.05');
      is ($annotation->{gene_taxonid}, '4896');
      is ($annotation->{publication_uniquename}, 'PMID:19756689');
      if ($annotation->{interacting_gene_identifier} eq 'SPBC14F5.07') {
        is ($annotation->{evidence_code}, 'Synthetic Haploinsufficiency');
        $interacting_gene_count++
      } else {
        if ($annotation->{interacting_gene_identifier} eq 'SPAC27D7.13c') {
          is ($annotation->{evidence_code}, 'Far Western');
          $interacting_gene_count++
        } else {
          fail ("unknown interacting gene");
        }
      }
    }

    is ($interacting_gene_count, 2);
  }

  my @annotation_type_list = @{$config->{annotation_type_list}};

  my $allele_count = 0;

  for my $annotation_type_config (@annotation_type_list) {
    my ($completed_count, $annotations_ref) =
      Canto::Curs::Utils::get_annotation_table($config, $curs_schema,
                                                $annotation_type_config->{name});

    my @annotations = @$annotations_ref;

    for my $annotation_row (@annotations) {
      ok (length $annotation_row->{annotation_type} > 0);
      ok (length $annotation_row->{evidence_code} > 0);

      if ($annotation_type_config->{category} eq 'ontology') {
        ok (length $annotation_row->{gene_name_or_identifier} > 0);
        ok (length $annotation_row->{term_ontid} > 0);
        ok (length $annotation_row->{term_name} > 0);

        if ($annotation_type_config->{needs_allele}) {
          ok (length $annotation_row->{allele_display_name} > 0);
          $allele_count++;
        }
      }
    }
  }
  ok ($allele_count > 0);

}

check_new_annotations();

# change an ontid to an alt_id
my $an_rs = $curs_schema->resultset('Annotation');
my $dummy_alt_id = "GO:123456789";
my $made_alt_id_change = 0;

while (defined (my $an = $an_rs->next())) {
  my $data = $an->data();

  if (defined $data->{term_ontid} && $data->{term_ontid} eq "GO:0055085") {
    $made_alt_id_change = 1;
    $data->{term_ontid} = $dummy_alt_id;
    $an->data($data);
    $an->update();
  }
}

ok($made_alt_id_change);

check_new_annotations($dummy_alt_id);


{
  my $options = { pub_uniquename => 'PMID:10467002',
                  annotation_type_name => 'cellular_component',
                };
  my ($all_annotation_count, $annotations) =
    Canto::Curs::Utils::get_existing_annotations($config, $options);

  is (@$annotations, 1);
  cmp_deeply($annotations->[0],
             {
               'taxonid' => '4896',
               'annotation_type' => 'cellular_component',
               'term_ontid' => 'GO:0030133',
               'term_name' => 'transport vesicle',
               'with_or_from_identifier' => undef,
               'gene_identifier' => 'SPBC12C2.02c',
               'gene_name_or_identifier' => 'ste20',
               'allele_display_name' => 'noname(unknown)',
               'conditions' => '',
               'expression_level' => '',
               'qualifiers' => '',
               'evidence_code' => 'IMP',
               'annotation_id' => 1,
               'gene_name' => 'ste20',
               'gene_product' => '',
               'is_not' => 0,
               'status' => 'existing',
               'with_or_from_display_name' => 'GeneDB_Spombe:SPBC2G2.01c',
               'with_or_from_identifier' => 'GeneDB_Spombe:SPBC2G2.01c',
             });
}

{
  my $options = { pub_uniquename => 'PMID:10467002',
                  annotation_type_name => 'biological_process',
                };
  my ($all_annotation_count, $annotations) =
    Canto::Curs::Utils::get_existing_ontology_annotations ($config, $options);

  is (@$annotations, 1);
  cmp_deeply($annotations->[0],
             {
               'taxonid' => '4896',
               'annotation_type' => 'biological_process',
               'term_ontid' => 'GO:0006810',
               'term_name' => 'transport [requires_direct_regulator] SPCC1739.11c',
               'with_or_from_identifier' => undef,
               'gene_identifier' => 'SPBC12C2.02c',
               'gene_name_or_identifier' => 'ste20',
               'qualifiers' => '',
               'allele_display_name' => 'noname(unknown)',
               'conditions' => '',
               'expression_level' => '',
               'evidence_code' => 'UNK',
               'annotation_id' => 2,
               'gene_name' => 'ste20',
               'gene_product' => '',
               'is_not' => 0,
               'status' => 'existing',
               'with_or_from_display_name' => undef,
               'with_or_from_identifier' => undef,
             });
}

sub _test_interactions
{
  my ($expected_count, @annotations) = @_;

  is (@annotations, $expected_count);
  cmp_deeply($annotations[0],
             {
               'gene_identifier' => 'SPBC12C2.02c',
               'gene_display_name' => 'ste20',
               'gene_taxonid' => '4896',
               'interacting_gene_identifier' => 'SPCC1739.11c',
               'interacting_gene_display_name' => 'cdc11',
               'interacting_gene_taxonid' => '4896',
               'evidence_code' => 'Phenotypic Enhancement',
               'publication_uniquename' => 'PMID:10467002',
               'status' => 'existing',
           });
}

{
  my $options = { pub_uniquename => 'PMID:10467002',
                  annotation_type_name => 'genetic_interaction',
                  annotation_type_category => 'interaction', };
  my ($all_interactions_count, $annotations) =
    Canto::Curs::Utils::get_existing_interaction_annotations ($config, $options);

  _test_interactions(2, @$annotations);
}

{
  my $options = { pub_uniquename => 'PMID:10467002',
                  annotation_type_name => 'genetic_interaction',
                  annotation_type_category => 'interaction',
                  max_results => 1, };
  my ($all_interactions_count, $annotations) =
    Canto::Curs::Utils::get_existing_interaction_annotations ($config, $options);

  _test_interactions(1, @$annotations);
}

{
  my $options = { pub_uniquename => 'PMID:10467002',
                  annotation_type_name => 'genetic_interaction',
                  annotation_type_category => 'interaction', };
  my ($all_interactions_count, $annotations) =
    Canto::Curs::Utils::get_existing_annotations($config, $options);

  _test_interactions(2, @$annotations);
}
