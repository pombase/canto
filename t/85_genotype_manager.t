use strict;
use warnings;
use Test::More tests => 42;

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
is (($genotype_from_chado->alleles())[0]->display_name($config), 'cdc11-33(unknown)');
is (($genotype_from_chado->alleles())[1]->display_name($config), 'ssm4delta');


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

my $ssm4_genotype = $found_genotype;

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
  expression => 'Overexpression',
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


# test that find_genotype() can find with diploids
my $find_results =
  $genotype_manager->find_genotype($pombe_taxonid, undef, undef,
                                   [$cdc11_delta_details, $cdc11_wt_allele_details],
                                   $curs_schema, $curs_key);


ok(defined $find_results);
is($find_results->display_name($config), "cdc11+[Overexpression] / cdc11delta");


# switch allele order:
$find_results =
  $genotype_manager->find_genotype($pombe_taxonid, undef, undef,
                                   [$cdc11_wt_allele_details, $cdc11_delta_details],
                                   $curs_schema, $curs_key);


ok(defined $find_results);
is($find_results->display_name($config), "cdc11+[Overexpression] / cdc11delta");

# deleting a genotype should delete unused Allele and Diploid objects
$genotype_manager->delete_genotype($diploid_genotype->genotype_id());

is($curs_schema->resultset('Diploid')->count(), 0);


# Test creation of homozygous diploid:

delete $cdc11_delta_details->{diploid_name};
my $cdc11_delta_genotype =
  $genotype_manager->make_genotype(undef, undef,
                                   [$cdc11_delta_details],
                                   $pombe_taxonid,
                                   undef, undef, undef);
my $found_cdc11_delta_genotype =
  $genotype_manager->find_genotype($pombe_taxonid, undef, undef,
                                   [$cdc11_delta_details],
                                   $curs_schema, $curs_key);

ok(defined $found_cdc11_delta_genotype);
is($found_cdc11_delta_genotype->display_name($config), "cdc11delta");

$cdc11_delta_details->{diploid_name} = 'diploid_1';

my $cdc11_delta_diplod_genotype =
  $genotype_manager->make_genotype(undef, undef,
                                   [$cdc11_delta_details, $cdc11_delta_details],
                                   $pombe_taxonid,
                                   undef, undef, undef);

my $found_cdc11_delta_diplod_genotype =
  $genotype_manager->find_genotype($pombe_taxonid, undef, undef,
                                   [$cdc11_delta_details, $cdc11_delta_details],
                                   $curs_schema, $curs_key);

ok(defined $found_cdc11_delta_diplod_genotype);
is($found_cdc11_delta_diplod_genotype->display_name($config), "cdc11delta / cdc11delta");

$genotype_manager->delete_genotype($found_cdc11_delta_diplod_genotype->genotype_id());


# check deletion
my $found_cdc11_delta_haploid_genotype =
  $genotype_manager->find_genotype($pombe_taxonid, undef, undef,
                                   [$cdc11_delta_details, $cdc11_delta_details],
                                   $curs_schema, $curs_key);

ok(!defined $found_cdc11_delta_haploid_genotype);


# Test creation of homozygous diploid where there is an existing
# non-diploid gentoype with the same allele twice

delete $cdc11_delta_details->{diploid_name};
my $cdc11_delta_haploid_genotype =
  $genotype_manager->make_genotype(undef, undef,
                                   [$cdc11_delta_details, $cdc11_delta_details],
                                   $pombe_taxonid,
                                   undef, undef, undef);
$found_cdc11_delta_haploid_genotype =
  $genotype_manager->find_genotype($pombe_taxonid, undef, undef,
                                   [$cdc11_delta_details, $cdc11_delta_details],
                                   $curs_schema, $curs_key);

ok(defined $found_cdc11_delta_haploid_genotype);
is($found_cdc11_delta_haploid_genotype->display_name($config), "cdc11delta cdc11delta");

$cdc11_delta_details->{diploid_name} = 'diploid_1';

$found_cdc11_delta_diplod_genotype =
  $genotype_manager->find_genotype($pombe_taxonid, undef, undef,
                                   [$cdc11_delta_details, $cdc11_delta_details],
                                   $curs_schema, $curs_key);

ok(!defined $found_cdc11_delta_diplod_genotype);


# test creating and deleting metagenotypes

my $genotype_rs = $curs_schema->resultset('Genotype');

my $first_genotype = $genotype_rs->next();
my $second_genotype = $genotype_rs->next();
my $third_genotype = $genotype_rs->next();

ok (defined $third_genotype);

my $metagenotype_1 =
  $genotype_manager->make_metagenotype(interactor_a => $first_genotype,
                                       interactor_b => $second_genotype);

ok (defined $metagenotype_1);

is ($metagenotype_1->identifier(), 'aaaa0007-metagenotype-1');

$genotype_manager->delete_metagenotype($metagenotype_1->metagenotype_id());

# re-create the same metagenotype
$metagenotype_1 =
  $genotype_manager->make_metagenotype(interactor_a => $first_genotype,
                                       interactor_b => $second_genotype);

ok (defined $metagenotype_1);

is ($metagenotype_1->identifier(), 'aaaa0007-metagenotype-1');

my $metagenotype_2 =
  $genotype_manager->make_metagenotype(interactor_a => $first_genotype,
                                       interactor_b => $third_genotype);

ok (defined $metagenotype_2);

is ($metagenotype_2->identifier(), 'aaaa0007-metagenotype-2');


my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $curs_schema,
                                                   config => $config);

my $res = $service_utils->create_annotation({
  key => $curs_key,
  feature_id => $metagenotype_1->metagenotype_id(),
  feature_type => 'metagenotype',
  annotation_type => 'disease_formation_phenotype',
  term_ontid => 'FYPO:0002060',
  evidence_code => 'Microscopy',
  extension =>
    [
      [
        {
          'relation' => 'depends_on_metagenoype',
          'rangeType' => 'Metagenotype',
          'rangeValue' => $metagenotype_2->metagenotype_id(),
        }
      ]
    ],
});
