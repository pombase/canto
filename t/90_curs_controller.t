use strict;
use warnings;
use Test::More tests => 28;
use Test::Deep;

use Data::Compare;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

use Canto::TestUtil;
use Canto::Controller::Curs;
use Canto::Curs::Utils;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('1_curs');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();

my @known_genes = qw(SPCC1739.10 mot1 SPNCRNA.119);
my @id_matching_two_genes = qw(ssm4);
my @two_ids_matching_one_gene = qw(ste20 ste16);
my @unknown_genes = qw(dummy SPCC999999.99);

my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $curs_metadata_rs = $curs_schema->resultset('Metadata');

my $gene_manager = Canto::Curs::GeneManager->new(config => $config,
                                                 curs_schema => $curs_schema);

my %metadata = ();

while (defined (my $metadata = $curs_metadata_rs->next())) {
  $metadata{$metadata->key()} = $metadata->value();
}

my $curs_db_pub = $curs_schema->resultset('Pub')->first();

is($metadata{curation_pub_id}, $curs_db_pub->pub_id());
like($curs_db_pub->title(), qr/Inactivating pentapeptide insertions in the/);


my @search_list = (@known_genes, @unknown_genes);

my ($result) =
  $gene_manager->find_and_create_genes(\@search_list);

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

  ok(grep { $_->{primary_identifier} eq 'SPBC1826.01c' } @res_found);

  is($curs_schema->resultset('Gene')->count(), $gene_count);
}

check_result($result, 2, 3, 0);

($result) = $gene_manager->find_and_create_genes(\@search_list);

check_result($result, 2, 3, 0);

my @results = $gene_manager->find_and_create_genes(\@known_genes);

ok(@results == 1);

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
  $gene_manager->_filter_existing_genes(@genes_to_filter);

is(@filtered_genes, 1);
is($filtered_genes[0]->{primary_identifier}, 'SPCC1739.11c');


# try some lists that fail
$curs_schema->resultset('Gene')->delete();

my ($identifiers_matching_more_than_once, $genes_matched_more_than_once);

($result, $identifiers_matching_more_than_once, $genes_matched_more_than_once) =
  $gene_manager->find_and_create_genes([@known_genes,
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
  $gene_manager->find_and_create_genes([@known_genes,
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
my $iso_date = Canto::Curs::Utils::get_iso_date();
like ($iso_date, qr(^\d+-\d+-\d+$));


# test _get_all_alleles() - make some allele and gene data first

my $pub_for_allele = $curs_schema->resultset('Pub')->first();

$gene_manager->find_and_create_genes(\@known_genes);

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


my %allele_data_1 = Canto::Controller::Curs::_get_all_alleles($config, $curs_schema,
                                                               $gene_for_allele);

is (scalar(keys %allele_data_1), 1);

done_testing;
