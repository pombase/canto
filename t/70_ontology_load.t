use strict;
use warnings;
use Test::More tests => 28;

use Data::Compare;

use PomCur::TestUtil;
use PomCur::Track::OntologyLoad;
use PomCur::Track::OntologyIndex;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('empty_db', { copy_ontology_index => 0 });

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @loaded_cvterms = $schema->resultset('Cvterm')->all();

is (@loaded_cvterms, 22);

my $test_go_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_go_obo_file};
my $test_relationship_ontology_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_relationship_obo_file};

my $ontology_index = PomCur::Track::OntologyIndex->new(config => $config);
$ontology_index->initialise_index();
my $ontology_load = PomCur::Track::OntologyLoad->new(schema => $schema);
my $synonym_types = $config->{load}->{ontology}->{synonym_types};

$ontology_load->load($test_relationship_ontology_file, undef, $synonym_types);
$ontology_load->load($test_go_file, $ontology_index, $synonym_types);

my $psi_mod_obo_file = $config->{test_config}->{test_psi_mod_obo_file};
$ontology_load->load($psi_mod_obo_file, $ontology_index, $synonym_types);

$ontology_index->finish_index();

@loaded_cvterms = $schema->resultset('Cvterm')->all();

is(@loaded_cvterms, 86);

ok(grep {
  $_->name() eq 'regulation of transmembrane transport'
} @loaded_cvterms);

ok(grep {
  $_->name() eq 'negative regulation of transmembrane transport' &&
    ($_->cvtermsynonym_cvterms()->first()->synonym() eq
       'down regulation of transmembrane transport' ||
         $_->cvtermsynonym_cvterms()->first()->synonym() eq
           'inhibition of transmembrane transport')
} @loaded_cvterms);


# biological_process
my $hits =
  $ontology_index->lookup('biological_process', 'transmembrane transport()\:-', 100);

my $num_hits = $hits->length();

for (my $i = 0; $i < $num_hits; $i++) {
  my $doc = $hits->doc($i);
  my $cv_name = $doc->get('cv_name');

  is($cv_name, 'biological_process');
}

is($hits->doc(0)->get('name'), 'transmembrane transport');
is($hits->doc(1)->get('name'), 'protein transmembrane transport');


# psi-mod
$hits = $ontology_index->lookup('psi-mod', 'secondary neutral', 100);

$num_hits = $hits->length();

is($num_hits, 3);

for (my $i = 0; $i < $num_hits; $i++) {
  my $doc = $hits->doc($i);
  my $cv_name = $doc->get('cv_name');

  is($cv_name, 'psi_mod');
}

is($hits->doc(0)->get('name'), 'modified residue with a secondary neutral loss');


# molecular_function with synonym
my $long_ugly_synonym =
  '(2-amino-4-hydroxy-7,8-dihydropteridin-6-yl)methyl-diphosphate:4-aminobenzoate ' .
  '2-amino-4-hydroxydihydropteridine-6-methenyltransferase activity';
$hits = $ontology_index->lookup('molecular_function',
                                $long_ugly_synonym, 100);

$num_hits = $hits->length();

is($num_hits, 6);

for (my $i = 0; $i < $num_hits; $i++) {
  my $doc = $hits->doc($i);
  my $cv_name = $doc->get('cv_name');

  is($cv_name, 'molecular_function');
}

is($hits->doc(0)->get('name'), 'dihydropteroate synthase activity');

my $ugly_synonym_substring =
  ',8-dihydropteridin-6-yl)methyl-diphosphate:4-aminobenzoate methenyltransferase';
$hits = $ontology_index->lookup('molecular_function',
                                $ugly_synonym_substring, 100);

$num_hits = $hits->length();

is($hits->doc(0)->get('cv_name'), 'molecular_function');

is($hits->doc(0)->get('name'), 'dihydropteroate synthase activity');

