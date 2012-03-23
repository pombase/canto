use strict;
use warnings;
use Test::More tests => 27;
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

done_testing;
