use strict;
use warnings;
use Test::More tests => 4;

use Canto::TestUtil;
use Canto::Curs::AlleleManager;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
$config->{implementation_classes}->{allele_adaptor} =
  'Canto::Chado::AlleleLookup';
$config->{implementation_classes}->{genotype_adaptor} =
  'Canto::Chado::GenotypeLookup';

my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 2);

my $curs_key = 'aaaa0007';

my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);


my $allele_manager = Canto::Curs::AlleleManager->new(config => $config,
                                                     curs_schema => $curs_schema);

my $SPCC576_16c = $curs_schema->resultset('Gene')->find({
  primary_identifier => 'SPCC576.16c',
});

is ($SPCC576_16c->primary_identifier(), 'SPCC576.16c');

my $new_allele = $allele_manager->allele_from_json(
  {
    type => 'partial deletion, amino acid',
    description => '100-200',
    name => 'SPCC576.16c-c1',
    gene_id => $SPCC576_16c->gene_id()
  },
  'aaaa0007');

is ($new_allele->primary_identifier(), 'SPCC576.16c:aaaa0007-1');

my $existing_allele_identifier = 'SPAC27D7.13c:aaaa0007-4';
my $existing_allele = $allele_manager->allele_from_json(
  {
    primary_identifier => $existing_allele_identifier,
  });

is ($existing_allele->primary_identifier(), $existing_allele_identifier);

