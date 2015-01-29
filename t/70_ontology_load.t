use strict;
use warnings;
use Test::More tests => 45;

use Canto::TestUtil;
use Canto::Track::OntologyLoad;
use Canto::Track::OntologyIndex;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('empty_db', { copy_ontology_index => 0 });

my $config = $test_util->config();
my $schema = Canto::TrackDB->new(config => $config);

my @loaded_cvterms = $schema->resultset('Cvterm')->all();

is (@loaded_cvterms, 72);

my $test_go_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_go_obo_file};
my $test_fypo_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_phenotype_obo_file};
my $test_relationship_ontology_file =
  $test_util->root_dir() . '/' . $config->{relationship_ontology_path};
my $psi_mod_obo_file = $config->{test_config}->{test_psi_mod_obo_file};

my $synonym_types = $config->{load}->{ontology}->{synonym_types};

sub load_all {
  my $ontology_index = shift;
  my $include_ro = shift;
  my $include_fypo = shift;

  my @relationships_to_load = @{$config->{load}->{ontology}->{relationships_to_load}};

  my $ontology_load =
    Canto::Track::OntologyLoad->new(schema => $schema,
                                    relationships_to_load => \@relationships_to_load,
                                    default_db_name => 'Canto');

  $ontology_index->initialise_index();

  if ($include_ro) {
    $ontology_load->load($test_relationship_ontology_file, undef, $synonym_types);
  }
  $ontology_load->load($test_go_file, $ontology_index, $synonym_types);
  if ($include_fypo) {
    $ontology_load->load($test_fypo_file, $ontology_index, $synonym_types);
  }
  $ontology_load->load($psi_mod_obo_file, $ontology_index, $synonym_types);

  $ontology_load->finalise();
  $ontology_index->finish_index();
}

my $index_path = $config->data_dir_path('ontology_index_dir');
my $ontology_index = Canto::Track::OntologyIndex->new(index_path => $index_path);

load_all($ontology_index, 1);

@loaded_cvterms = $schema->resultset('Cvterm')->all();

is(@loaded_cvterms, 114);

my @cvterm_relationships = $schema->resultset('CvtermRelationship')->all();

is(@cvterm_relationships, 34);

ok((grep {
  $_->name() eq 'regulation of transmembrane transport'
} @loaded_cvterms), 'has transmembrane transport term name');

ok(grep {
  $_->name() eq 'negative regulation of transmembrane transport' &&
    ($_->cvtermsynonym_cvterms()->first()->synonym() eq
       'down regulation of transmembrane transport' ||
         $_->cvtermsynonym_cvterms()->first()->synonym() eq
           'inhibition of transmembrane transport')
} @loaded_cvterms);


# biological_process
my @results =
  $ontology_index->lookup('biological_process', 'transmembrane transport', 100);

for my $result (@results) {
  my $doc = $result->{doc};
  my $cv_name = $doc->get('cv_name');

  my $cvterm_id = $doc->get('cvterm_id');
  my $cvterm = $schema->find_with_type('Cvterm', $cvterm_id);

  is($cv_name, 'biological_process');
}

is(@results, 7);

my @expected_transport = (
  "transmembrane transport",
  "protein transmembrane transport",
  "regulation of transmembrane transport",
  "hydrogen peroxide transmembrane transport",
  "negative regulation of transmembrane transport",
  "positive regulation of transmembrane transport",
);

for (my $i = 0; $i < @expected_transport; $i++) {
  is($results[$i]->{doc}->get('term_name'), $expected_transport[$i]);
}


# psi-mod
@results = $ontology_index->lookup('psi-mod', 'secondary neutral', 100);

is(@results, 3);

for my $result (@results) {
  my $doc = $result->{doc};
  my $cv_name = $doc->get('cv_name');

  is($cv_name, 'psi_mod');
}

is($results[0]->{doc}->get('term_name'), 'modified residue with a secondary neutral loss');


# molecular_function with synonym
my $long_ugly_synonym_query = 'aminobenzoate methenyltransferase activity';
@results = $ontology_index->lookup('molecular_function', $long_ugly_synonym_query, 100);

is(@results, 6);

for my $result (@results) {
  my $doc = $result->{doc};
  my $cv_name = $doc->get('cv_name');

  is($cv_name, 'molecular_function');
}

is($results[0]->{doc}->get('text'), '2-amino-4-hydroxy-6-hydroxymethyl-7,8-dihydropteridine-diphosphate:4-aminobenzoate 2-amino-4-hydroxydihydropteridine-6-methenyltransferase activity');
is($results[0]->{doc}->get('term_name'), 'dihydropteroate synthase activity');

@results = $ontology_index->lookup('molecular_function',
                                   'dihydropteroate synthetase activity', 100);

is(@results, 6);
is($results[0]->{doc}->get('cv_name'), 'molecular_function');
is($results[0]->{doc}->get('text'), 'dihydropteroate synthetase activity');
is($results[0]->{doc}->get('term_name'), 'dihydropteroate synthase activity');


# check loading of alt_ids
my $cvterm_dbxref_rs = $schema->resultset('CvtermDbxref');
is($cvterm_dbxref_rs->count(), 34);

undef $ontology_index;

$ontology_index = Canto::Track::OntologyIndex->new(index_path => $index_path);

# try re-loading
load_all($ontology_index);
is($cvterm_dbxref_rs->count(), 34);

undef $ontology_index;

$ontology_index = Canto::Track::OntologyIndex->new(index_path => $index_path);

# test that obsolete terms are loaded but aren't indexed by Lucene
load_all($ontology_index, 1, 1);
@loaded_cvterms = $schema->resultset('Cvterm')->all();

is(@loaded_cvterms, 133);

ok((grep {
  $_->name() eq 'viable elongated vegetative cell population'
} @loaded_cvterms), '"viable elongated vegetative cell population" missing');

# test that non-obsolete term is indexed
my $viable = 'viable vegetative cell population';
@results = $ontology_index->lookup('fission_yeast_phenotype', $viable, 100);
is(@results, 7);

ok((grep {
  $_->{term_name} eq $viable;
} @results), qq("$viable" missing));


# test that obsolete terms aren't indexed
my $viable_elongated = 'viable elongated vegetative cell population';
@results = $ontology_index->lookup('fission_yeast_phenotype', $viable_elongated, 100);
is(@results, 7);

ok(!(grep {
  $_->{term_name} eq $viable_elongated;
} @results), qq("$viable_elongated" shouldn't be returned));

undef $ontology_index;
