use strict;
use warnings;
use Test::More tests => 17;

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

is ($curs_schema->resultset('Allele')->count(), 5);

my $genotype_manager = Canto::Curs::GenotypeManager->new(config => $config,
                                                         curs_schema => $curs_schema);

$genotype_manager->_remove_unused_alleles();
is ($curs_schema->resultset('Allele')->count(), 3);

my $created_genotype_identifier = $curs_key . '-test-genotype-3';

my $genotype_from_chado =
  $genotype_manager->find_and_create_genotype($created_genotype_identifier);

my $genotype_name = 'cdc11-33 ssm4delta';

is ($genotype_from_chado->identifier(), $created_genotype_identifier);
is ($genotype_from_chado->name(), $genotype_name);
is ($genotype_from_chado->alleles(), 2);
is (($genotype_from_chado->alleles())[0]->display_name(), 'cdc11-33(unknown)');
is (($genotype_from_chado->alleles())[1]->display_name(), 'ssm4delta');


is ($curs_schema->resultset('Genotype')->find({ identifier => $created_genotype_identifier })
      ->identifier(), $created_genotype_identifier);



# test find_with_bg_and_alleles()
my $cdc11_allele =
  $curs_schema->resultset('Allele')->find({ name => 'cdc11-33' });
ok($cdc11_allele);

my $ssm4_allele =
  $curs_schema->resultset('Allele')->find({ name => 'ssm4delta' });
ok ($ssm4_allele);

my $found_genotype = $genotype_manager->find_with_bg_and_alleles(undef, [$cdc11_allele]);
ok(!defined $found_genotype);

$found_genotype = $genotype_manager->find_with_bg_and_alleles(undef, [$ssm4_allele]);
ok(!defined $found_genotype);

$found_genotype = $genotype_manager->find_with_bg_and_alleles(undef, [$ssm4_allele, $cdc11_allele]);
ok(defined $found_genotype);
is($found_genotype->name(), $genotype_name);

$found_genotype = $genotype_manager->find_with_bg_and_alleles('new-background-name',
                                                              [$ssm4_allele, $cdc11_allele]);
ok(!defined $found_genotype);


#test delete_genotype()
try {
  $genotype_manager->delete_genotype($genotype_from_chado->genotype_id());
} catch {
  fail($_);
};

my $deleted_genotype = $curs_schema->resultset('Genotype')->find({ identifier => $created_genotype_identifier });

ok(!defined($deleted_genotype));
