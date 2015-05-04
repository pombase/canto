use strict;
use warnings;
use Test::More tests => 7;

use Try::Tiny;

use Canto::TestUtil;
use Canto::Curs::GenotypeManager;

my $test_util = Canto::TestUtil->new('t/chado_test_config.yaml');
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


my $genotype_manager = Canto::Curs::GenotypeManager->new(config => $config,
                                                         curs_schema => $curs_schema);

my $created_genotype_identifier = $curs_key . '-test-genotype-3';

my $genotype_from_chado =
  $genotype_manager->find_and_create_genotype($created_genotype_identifier);

is ($genotype_from_chado->identifier(), $created_genotype_identifier);
is ($genotype_from_chado->name(), 'h+ cdc11-33 ssm4delta');
is ($genotype_from_chado->alleles(), 1);
is (($genotype_from_chado->alleles())[0]->display_name(), 'ssm4delta');


is ($curs_schema->resultset('Genotype')->find({ identifier => $created_genotype_identifier })
      ->identifier(), $created_genotype_identifier);


try {
  $genotype_manager->delete_genotype($genotype_from_chado->genotype_id());
} catch {
  fail($_);
};


my $deleted_genotype = $curs_schema->resultset('Genotype')->find({ identifier => $created_genotype_identifier });

ok(!defined($deleted_genotype));
