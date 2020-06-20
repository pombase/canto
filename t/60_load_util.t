use strict;
use warnings;
use Test::More tests => 26;
use Test::Exception;

use Canto::TestUtil;
use Canto::Track::LoadUtil;
use Canto::Track::GeneLoad;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $schema = $test_util->track_schema();

my $load_util = Canto::Track::LoadUtil->new(schema => $schema);

my $dbxref = $load_util->find_dbxref("PECO:0000005");

is($dbxref->accession(), "0000005");
is($dbxref->db()->name(), "PECO");

throws_ok { $load_util->find_dbxref("no_such_id"); } qr/not in the form/;
my $no_such_id = "db:no_such_id";
throws_ok { $load_util->find_dbxref($no_such_id); } qr/no Dbxref found for $no_such_id/;


# test adding sessions for a JSON file - mostly used by Fly-Canto
my $fly = $load_util->get_organism('Drosophila melanogaster', '7227', 'fruit fly');
my $gene_load = Canto::Track::GeneLoad->new(organism => $fly, schema => $schema);
$gene_load->create_gene('FBgn0004107', 'Dmel\Cdk2', [], 'Cyclin-dependent kinase 2');
$gene_load->create_gene('FBgn0016131', 'Dmel\Cdk4', [], 'Cyclin-dependent kinase 4');
my $test_json_file = $test_util->root_dir() . '/t/data/sessions_from_json_test.json';
my ($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);

is (@$created_sessions, 1);
is (@$updated_sessions, 0);

my $created_curs = $created_sessions->[0];
my $created_cursdb = Canto::Curs::get_schema_for_key($config, $created_curs->curs_key());

my $FBal0119310_allele =
  $created_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0119310" });

ok (defined $FBal0119310_allele);

is($FBal0119310_allele->type(), 'other');
is($FBal0119310_allele->name(), 'Dmel\Cdk2_UAS.Tag:MYC');
is($FBal0119310_allele->description(), 'description of FBal0119310');
is($FBal0119310_allele->comment(), 'comment on FBal0119310');

my $genotype_FBal0119310 =
  $created_cursdb->resultset('Genotype')->find({ identifier => "genotype-FBal0119310" });

my $FBal0119310_genotype_allele = ($genotype_FBal0119310->alleles()->all())[0];
is ($FBal0119310_genotype_allele->allele_id(), $FBal0119310_allele->allele_id());

is($FBal0119310_allele->name(), 'Dmel\Cdk2_UAS.Tag:MYC');

my @FBal0119310_allelesynonyms = sort map { $_->synonym() } $FBal0119310_allele->allelesynonyms()->all();
is (@FBal0119310_allelesynonyms, 2);
is ($FBal0119310_allelesynonyms[0], "UAS-Cdk2");
is ($FBal0119310_allelesynonyms[1], "UAS-Cdk2-myc");

my $genotype_FBab0037918 =
  $created_cursdb->resultset('Genotype')->find({ identifier => "genotype-FBab0037918" });

my $FBab0037918_allele = ($genotype_FBab0037918->alleles()->all())[0];

is($FBab0037918_allele->name(), 'Df(2L)Exel7046');


# load the same file to test session updating
($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);

is (@$created_sessions, 0);
is (@$updated_sessions, 0);

# load an extra allele
my $test_json_extra_allele_file =
  $test_util->root_dir() . '/t/data/sessions_from_json_extra_allele_test.json';
($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_extra_allele_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);

is (@$created_sessions, 0);
is (@$updated_sessions, 1);

my $updated_curs = $updated_sessions->[0];
my $updated_cursdb = Canto::Curs::get_schema_for_key($config, $updated_curs->curs_key());

my $FBal0098765_allele =
  $created_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0098765" });

ok (defined $FBal0098765_allele);

is($FBal0098765_allele->type(), 'other');
is($FBal0098765_allele->name(), 'Dmel\Cdk4_d1234');
is($FBal0098765_allele->description(), undef);
is($FBal0098765_allele->comment(), undef);
