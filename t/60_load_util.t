use strict;
use warnings;
use Test::More tests => 61;
use Test::Exception;

use Canto::TestUtil;
use Canto::Track::LoadUtil;
use Canto::Track::GeneLoad;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $schema = $test_util->track_schema();

my $load_util = Canto::Track::LoadUtil->new(schema => $schema);

my $dbxref = $load_util->find_dbxref("FYECO:0000005");

is($dbxref->accession(), "0000005");
is($dbxref->db()->name(), "FYECO");

throws_ok { $load_util->find_dbxref("no_such_id"); } qr/not in the form/;
my $no_such_id = "db:no_such_id";
throws_ok { $load_util->find_dbxref($no_such_id); } qr/no Dbxref found for $no_such_id/;


# test adding sessions for a JSON file - mostly used by Fly-Canto
my $fly = $load_util->get_organism('Drosophila melanogaster', '7227', 'fruit fly');
my $gene_load = Canto::Track::GeneLoad->new(organism => $fly, schema => $schema);
$gene_load->create_gene('FBgn0004107', 'Dmel\Cdk2', [], 'Cyclin-dependent kinase 2');
$gene_load->create_gene('FBgn0016131', 'Dmel\Cdk4', [], 'Cyclin-dependent kinase 4');
$gene_load->create_gene('FBgn0008888', 'Dmel\Cdk88', [], 'kinase 88');
$gene_load->create_gene('FBgn0009999', 'Dmel\Cdk99', [], 'kinase 99');
my $test_json_file = $test_util->root_dir() . '/t/data/sessions_from_json_test.json';
my ($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);

is (@$created_sessions, 1);
is (@$updated_sessions, 0);

my $created_curs = $created_sessions->[0];
my $created_cursdb = Canto::Curs::get_schema_for_key($config, $created_curs->curs_key());

my $notes_rs = $created_cursdb->resultset('Metadata')->search({ key => 'external_notes' });
is($notes_rs->count(), 1);
is($notes_rs->first()->value(), "test notes\nline 2");

my $FBal0119310_allele =
  $created_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0119310" });

ok (defined $FBal0119310_allele);

is($FBal0119310_allele->type(), 'other');
is($FBal0119310_allele->name(), 'Dmel\Cdk2_UAS.Tag:MYC');
is($FBal0119310_allele->description(), 'description of FBal0119310');
is($FBal0119310_allele->comment(), 'comment on FBal0119310');

my @FBal0119310_genotypes = $FBal0119310_allele->genotypes();

is (@FBal0119310_genotypes, 1);


my @FBal0119310_allelesynonyms = sort map { $_->synonym() } $FBal0119310_allele->allelesynonyms()->all();
is (@FBal0119310_allelesynonyms, 2);
is ($FBal0119310_allelesynonyms[0], "UAS-Cdk2");
is ($FBal0119310_allelesynonyms[1], "UAS-Cdk2-myc");


my $FBab0037918_allele =
  $created_cursdb->resultset('Allele')->find({ primary_identifier => "FBab0037918" });
is($FBab0037918_allele->name(), 'Df(2L)Exel7046');

my @FBab0037918_genotypes = $FBal0119310_allele->genotypes();

is (@FBab0037918_genotypes, 1);



# load the same file to test session updating
($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);

is (@$created_sessions, 0);
is (@$updated_sessions, 0);

$notes_rs = $created_cursdb->resultset('Metadata')->search({ key => 'external_notes' });
is($notes_rs->count(), 1);
is($notes_rs->first()->value(), "test notes\nline 2");


# load a file with allele and gene ID changes (via the "secondary_identifiers" field)
my $test_json_id_changes_file =
  $test_util->root_dir() . '/t/data/sessions_from_json_id_changes_test.json';

my $FBal0064432_allele =
  $created_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0064432" });
$FBal0064432_allele->primary_identifier("FBal0064432-sec-test");
$FBal0064432_allele->update();
my $FBal0064432_old_id_allele =
  $created_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0064432-sec-test" });
ok(defined $FBal0064432_old_id_allele);

my $FBgn0016131_gene =
  $created_cursdb->resultset('Gene')->find({ primary_identifier => "FBgn0016131" });
$FBgn0016131_gene->primary_identifier("FBgn0016131-sec-test");
$FBgn0016131_gene->update();
my $FBgn0016131_old_id_gene =
  $created_cursdb->resultset('Gene')->find({ primary_identifier => "FBgn0016131-sec-test" });
ok(defined $FBgn0016131_old_id_gene);

($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_id_changes_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);

is (@$created_sessions, 0);
is (@$updated_sessions, 1);

$FBal0064432_old_id_allele =
  $created_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0064432-sec-test" });
ok(!defined $FBal0064432_old_id_allele);

$FBal0064432_allele =
  $created_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0064432" });
ok(defined $FBal0064432_allele);


$FBal0119310_allele =
  $created_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0119310" });
# new name:
is($FBal0119310_allele->name(), "Dmel\\Cdk2-new-name");
# new type:
is($FBal0119310_allele->type(), 'accessory');

$FBgn0016131_old_id_gene =
  $created_cursdb->resultset('Gene')->find({ primary_identifier => "FBgn0016131-sec-test" });
ok(!defined $FBgn0016131_old_id_gene);

$FBgn0016131_gene =
  $created_cursdb->resultset('Gene')->find({ primary_identifier => "FBgn0016131" });
ok(defined $FBgn0016131_gene);


# make sure we can reload the same file with ID changes
($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_id_changes_file,
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
  $updated_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0098765" });

ok (defined $FBal0098765_allele);

is($FBal0098765_allele->type(), 'other');
is($FBal0098765_allele->name(), 'Dmel\Cdk4_d1234');
is($FBal0098765_allele->description(), undef);
is($FBal0098765_allele->comment(), undef);


# load an extra gene
my $test_json_extra_gene_file =
  $test_util->root_dir() . '/t/data/sessions_from_json_extra_gene_test.json';
($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_extra_gene_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);

is (@$created_sessions, 0);
is (@$updated_sessions, 1);

$updated_curs = $updated_sessions->[0];
$updated_cursdb = Canto::Curs::get_schema_for_key($config, $updated_curs->curs_key());

my $FBgn0008888 =
  $updated_cursdb->resultset('Gene')->find({ primary_identifier => "FBgn0008888" });
ok (defined $FBgn0008888);



# make sure we can load it again
($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_extra_gene_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);

is (@$created_sessions, 0);
is (@$updated_sessions, 0);



# load an extra gene and an allele
my $test_json_extra_gene_and_allele_file =
  $test_util->root_dir() . '/t/data/sessions_from_json_extra_gene_and_allele_test.json';
($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_extra_gene_and_allele_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);

is (@$created_sessions, 0);
is (@$updated_sessions, 1);

$updated_curs = $updated_sessions->[0];
$updated_cursdb = Canto::Curs::get_schema_for_key($config, $updated_curs->curs_key());

my $FBgn0009999 =
  $updated_cursdb->resultset('Gene')->find({ primary_identifier => "FBgn0009999" });
ok (defined $FBgn0009999);

my $FBal0009999_allele =
  $updated_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0009999" });
is ($FBal0009999_allele->name(), 'Dmel\Cdk88_V1.allele');


# make sure we can load it again
($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_extra_gene_and_allele_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);

is (@$created_sessions, 0);
is (@$updated_sessions, 0);


# load a JSON file where some genes are removed
my $test_json_removed_genes_and_alleles_file =
  $test_util->root_dir() . '/t/data/sessions_from_json_removed_genes_alleles.json';

# gene and allele exists before:
$FBgn0009999 =
  $updated_cursdb->resultset('Gene')->find({ primary_identifier => "FBgn0009999" });
ok (defined $FBgn0009999);

my $FBal0119310 =
  $updated_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0119310" });
ok (defined $FBal0119310);


($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_removed_genes_and_alleles_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);


is (@$created_sessions, 0);
is (@$updated_sessions, 1);

# gene and allele gone after:
$FBgn0009999 =
  $updated_cursdb->resultset('Gene')->find({ primary_identifier => "FBgn0009999" });
ok (!defined $FBgn0009999);

$FBal0119310 =
  $updated_cursdb->resultset('Allele')->find({ primary_identifier => "FBal0119310" });
ok (!defined $FBal0119310);


# check that we can load it again without change
($created_sessions, $updated_sessions) =
  $load_util->create_sessions_from_json($config, $test_json_removed_genes_and_alleles_file,
                                        'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org', 7227);


is (@$created_sessions, 0);
is (@$updated_sessions, 0);
