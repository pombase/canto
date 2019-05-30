use strict;
use warnings;
use Test::More tests => 23;

use Try::Tiny;

use Canto::TestUtil;
use Canto::Curs::GenotypeManager;
use Canto::Curs::AlleleManager;

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

my $allele_manager = Canto::Curs::AlleleManager->new(config => $config,
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



# test find_genotype()
my $cdc11_allele =
  $curs_schema->resultset('Allele')->find({ name => 'cdc11-33' });
ok($cdc11_allele);

my $cdc11_gene = $cdc11_allele->gene();

my $cdc11_allele_details = {
  name => 'cdc11-33',
  gene_id => $cdc11_gene->gene_id(),
  type => 'unknown',
  description => 'unknown',
};

my $ssm4_allele =
  $curs_schema->resultset('Allele')->find({ name => 'ssm4delta' });
ok ($ssm4_allele);

my $ssm4_gene = $ssm4_allele->gene();

my $ssm4_allele_details = {
  name => 'ssm4delta',
  type => 'deletion',
  description => 'deletion',
  gene_id => $ssm4_gene->gene_id(),
};

my $pombe_taxonid = 4896;

my $found_genotype = $genotype_manager->find_genotype($pombe_taxonid, undef, undef, [$cdc11_allele_details]);
ok(!defined $found_genotype);

$found_genotype = $genotype_manager->find_genotype($pombe_taxonid, undef, undef, [$ssm4_allele_details]);
ok(!defined $found_genotype);

$found_genotype = $genotype_manager->find_genotype($pombe_taxonid, undef, undef, [$ssm4_allele_details, $cdc11_allele_details]);
ok(defined $found_genotype);

is($found_genotype->name(), $genotype_name);

$found_genotype = $genotype_manager->find_genotype($pombe_taxonid, 'new-background-name', undef,
                                                   [$ssm4_allele_details, $cdc11_allele_details]);
ok(!defined $found_genotype);

#test delete_genotype()
try {
  $genotype_manager->delete_genotype($genotype_from_chado->genotype_id());
} catch {
  fail($_);
};

my $deleted_genotype = $curs_schema->resultset('Genotype')->find({ identifier => $created_genotype_identifier });

ok(!defined($deleted_genotype));


# test diploids

my $cdc11_wt_allele_details = {
  gene_id => $cdc11_gene->gene_id(),
  type => 'wild type',
  diploid_name => 'diploid_1',
};

my $cdc11_delta_details = {
  gene_id => $cdc11_gene->gene_id(),
  type => 'deletion',
  name => 'cdc11delta',
  diploid_name => 'diploid_1',
};

my $diploid_genotype =
  $genotype_manager->make_genotype(undef, undef,
                                   [$cdc11_delta_details, $cdc11_wt_allele_details],
                                   $pombe_taxonid,
                                   undef, undef, undef);

my $diploid_genotype_identifier = $diploid_genotype->identifier();

is($curs_schema->resultset('Diploid')->count(), 1);

ok(defined $diploid_genotype);

my $cdc11_diploid = $curs_schema->resultset('Diploid')->next();

ok($cdc11_diploid->name() =~ /canto-genotype-temp-\d+-SPCC1739.11c:aaaa0007-1--SPCC1739.11c:aaaa0007-2/);

ok(defined $cdc11_diploid);

is($cdc11_diploid->allele_genotypes()->count(), 2);

# deleting a genotype should delete unused Allele and Diploid objects
$genotype_manager->delete_genotype($diploid_genotype->genotype_id());

is($curs_schema->resultset('Diploid')->count(), 0);
