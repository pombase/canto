use strict;
use warnings;
use Test::More tests => 43;
use Test::Deep;

use Data::Compare;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

use PomCur::TestUtil;
use PomCur::Controller::Curs;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('1_curs');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();

my @known_genes = qw(SPCC1739.10 wtf22 SPNCRNA.119);
my @id_matching_two_genes = qw(ssm4);
my @two_ids_matching_one_gene = qw(ste20 ste16);
my @unknown_genes = qw(dummy SPCC999999.99);

my $curs_schema = PomCur::Curs::get_schema_for_key($config, $curs_key);

my $curs_metadata_rs = $curs_schema->resultset('Metadata');

my %metadata = ();

while (defined (my $metadata = $curs_metadata_rs->next())) {
  $metadata{$metadata->key()} = $metadata->value();
}

my $curs_db_pub = $curs_schema->resultset('Pub')->first();

is($metadata{first_contact_email}, 'nick.rhind@umassmed.edu');
is($metadata{curation_pub_id}, $curs_db_pub->pub_id());
like($curs_db_pub->title(), qr/Inactivating pentapeptide insertions in the/);


my @search_list = (@known_genes, @unknown_genes);

my ($result) =
  PomCur::Controller::Curs->_find_and_create_genes($curs_schema, $config,
                                                   \@search_list);
sub check_result
{
  my $result = shift;
  my $missing_count = shift;
  my $found_count = shift;
  my $gene_count = shift;

  my @res_missing = @{$result->{missing}};
  my @res_found = @{$result->{found}};

  is(@res_missing, $missing_count);

  ok(Compare(\@res_missing, \@unknown_genes));
  is(@res_found, $found_count);

  ok(grep { $_->{primary_identifier} eq 'SPCC576.16c' } @res_found);

  is($curs_schema->resultset('Gene')->count(), $gene_count);
}

check_result($result, 2, 3, 0);

($result) =
  PomCur::Controller::Curs->_find_and_create_genes($curs_schema, $config,
                                                   \@search_list);

check_result($result, 2, 3, 0);

($result) =
  PomCur::Controller::Curs->_find_and_create_genes($curs_schema, $config,
                                                   \@known_genes);

ok(!defined $result);

is($curs_schema->resultset('Gene')->count(), 3);


sub _lookup_gene
{
  my $primary_identifier = shift;

  my @genes =
    $track_schema->find_with_type('Gene',
                                  { primary_identifier => $primary_identifier });

  die if @genes != 1;

  return { primary_identifier => $genes[0]->primary_identifier(),
           primary_name => $genes[0]->primary_identifier(),
           product => $genes[0]->product(),
         };
}

my @gene_identifiers_to_filter = ('SPCC1739.11c', $known_genes[0], $known_genes[2]);

my @genes_to_filter =
  map { _lookup_gene($_)} @gene_identifiers_to_filter;

my @filtered_genes =
  PomCur::Controller::Curs->_filter_existing_genes($curs_schema,
                                                   @genes_to_filter);

is(@filtered_genes, 1);
is($filtered_genes[0]->{primary_identifier}, 'SPCC1739.11c');


# try some lists that fail
$curs_schema->resultset('Gene')->delete();

my ($identifiers_matching_more_than_once, $genes_matched_more_than_once);

($result, $identifiers_matching_more_than_once, $genes_matched_more_than_once) =
  PomCur::Controller::Curs->_find_and_create_genes($curs_schema, $config,
                                                   [@known_genes,
                                                    @id_matching_two_genes,
                                                    'SPCC576.19c']);
ok(defined $result);
cmp_deeply($identifiers_matching_more_than_once,
           {
             ssm4 => [qw(SPAC27D7.13c SPBC14F5.07)],
           });
cmp_deeply($genes_matched_more_than_once, {});



is($curs_schema->resultset('Gene')->count(), 0);

($result, $identifiers_matching_more_than_once, $genes_matched_more_than_once) =
  PomCur::Controller::Curs->_find_and_create_genes($curs_schema, $config,
                                                   [@known_genes,
                                                    @two_ids_matching_one_gene,
                                                    'SPCC576.19c']);
ok(defined $result);
cmp_deeply($identifiers_matching_more_than_once, {});
cmp_deeply($genes_matched_more_than_once,
           {
             'SPBC12C2.02c' => [qw(ste16 ste20)],
           });



is($curs_schema->resultset('Gene')->count(), 0);



# utility methods
my $iso_date = PomCur::Controller::Curs::_get_iso_date();
like ($iso_date, qr(^\d+-\d+-\d+$));


# test _get_all_alleles() - make some allele and gene data first

my $pub_for_allele = $curs_schema->resultset('Pub')->first();

PomCur::Controller::Curs->_find_and_create_genes($curs_schema, $config,
                                                 \@known_genes);

my $gene_rs = $curs_schema->resultset('Gene');
is ($gene_rs->count(), 3);


my $annotation_for_allele =
  $curs_schema->create_with_type('Annotation',
                                 {
                                   type => 'phenotype',
                                   status => 'new',
                                   pub => $pub_for_allele,
                                   creation_date => $iso_date,
                                   data => {
                                     term_ontid => 'FYPO:0000013',
                                   },
                                 });

my $gene_for_allele = $gene_rs->find({ primary_identifier => "SPCC1739.10" });


my $allele =
  $curs_schema->create_with_type('Allele',
                                 {
                                   name => 'existing_allele_name',
                                   description => 'desc',
                                   primary_identifier => 'SPCC1739.10:allele-1',
                                   type => 'existing',
                                   gene => $gene_for_allele->gene_id(),
                                 });

$curs_schema->create_with_type('AlleleAnnotation',
                               {
                                 allele => $allele->allele_id(),
                                 annotation => $annotation_for_allele->annotation_id(),
                               });


my $annotation_for_rna_allele =
  $curs_schema->create_with_type('Annotation',
                                 {
                                   type => 'phenotype',
                                   status => 'new',
                                   pub => $pub_for_allele,
                                   creation_date => $iso_date,
                                   data => {
                                     term_ontid => 'FYPO:0000017',
                                   },
                                 });

my $rna_gene_for_allele = $gene_rs->find({ primary_identifier => "SPNCRNA.119" });


my $rna_allele =
  $curs_schema->create_with_type('Allele',
                                 {
                                   name => 'existing_rna_allele_name',
                                   description => 'rna_desc',
                                   primary_identifier => 'SPNCRNA.119:allele-2',
                                   type => 'existing',
                                   gene => $rna_gene_for_allele->gene_id(),
                                 });

$curs_schema->create_with_type('AlleleAnnotation',
                               {
                                 allele => $rna_allele->allele_id(),
                                 annotation => $annotation_for_rna_allele->annotation_id(),
                               });


my $annotation_for_allele_in_progress =
  $curs_schema->create_with_type('Annotation',
                                 {
                                   type => 'phenotype',
                                   status => 'new',
                                   pub => $pub_for_allele,
                                   creation_date => $iso_date,
                                   data => {
                                     term_ontid => 'FYPO:0000128',
                                   },
                                 });
$curs_schema->create_with_type('GeneAnnotation',
                               {
                                 gene => $gene_for_allele->gene_id(),
                                 annotation => $annotation_for_allele_in_progress->annotation_id(),
                               });

my %allele_creation_data_1 = (
  name => 'test_name_1',
  description => 'test_desc_1',
  conditions => ['cold'],
  evidence => 'Western blot assay',
  expression => 'Endogenous',
);

PomCur::Controller::Curs::_allele_add_action_internal($config, $curs_schema,
                                                      $annotation_for_allele_in_progress,
                                                      \%allele_creation_data_1);

is($annotation_for_allele_in_progress->data()->{alleles_in_progress}->{0}->{conditions}->[0], 'PCO:0000006');

my %allele_creation_data_2 = (
  name => 'an_allele',
  description => undef,
  conditions => ['cold', 'late in the afternoon'],
  evidence => 'Enzyme assay data',
  expression => 'Overexpression',
);

my $add_res =
  PomCur::Controller::Curs::_allele_add_action_internal($config, $curs_schema,
                                                        $annotation_for_allele_in_progress,
                                                        \%allele_creation_data_2);
my $add_expected = {
  'expression' => 'Overexpression',
  'name' => 'an_allele',
  'evidence' => 'Enzyme assay data',
  'id' => 1,
  'display_name' => 'an_allele(unknown)',
  'description' => undef,
  'conditions' => [
    'cold',
    'late in the afternoon'
  ]
};
cmp_deeply($add_res, $add_expected);


my %allele_data_1 = PomCur::Controller::Curs::_get_all_alleles($config, $curs_schema,
                                                               $gene_for_allele);

is (scalar(keys %allele_data_1), 3);

is ($allele_data_1{'test_name_1(test_desc_1)'}->{name}, $allele_creation_data_1{name});
is ($allele_data_1{'an_allele(unknown)'}->{description}, undef);
is ($allele_data_1{'existing_allele_name(desc)'}->{primary_identifier}, 'SPCC1739.10:allele-1');


my %allele_data_2 = PomCur::Controller::Curs::_get_all_alleles($config, $curs_schema,
                                                               $rna_gene_for_allele);

is (scalar(keys %allele_data_2), 1);

is ($allele_data_2{'existing_rna_allele_name(rna_desc)'}->{name}, 'existing_rna_allele_name');
is ($allele_data_2{'existing_rna_allele_name(rna_desc)'}->{description}, 'rna_desc');
is ($allele_data_2{'existing_rna_allele_name(rna_desc)'}->{primary_identifier}, 'SPNCRNA.119:allele-2');



my %allele_creation_data_3 = (
  name => '',
  description => 'unknown',
  evidence => 'Enzyme assay data',
  expression => 'Overexpression',
);

my $new_allele_data_3 =
  PomCur::Controller::Curs::_allele_add_action_internal($config, $curs_schema,
                                                        $annotation_for_allele,
                                                        \%allele_creation_data_3);


is (scalar(keys %$new_allele_data_3), 6);

is ($new_allele_data_3->{'expression'}, 'Overexpression');
is ($new_allele_data_3->{'name'}, '');
is ($new_allele_data_3->{'display_name'}, '(unknown)');
is ($new_allele_data_3->{'id'}, 0);


done_testing;
