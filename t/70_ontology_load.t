use strict;
use warnings;
use Test::More tests => 52;
use Test::Deep;

use Canto::TestUtil;
use Canto::Track::OntologyLoad;
use Canto::Track::OntologyIndex;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('empty_db', { copy_ontology_index => 0 });

my $config = $test_util->config();
my $schema = Canto::TrackDB->new(config => $config);

my @loaded_cvterms = $schema->resultset('Cvterm')->all();

is (@loaded_cvterms, 78);

my $test_go_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_go_obo_file};
my $test_fypo_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_phenotype_obo_file};
my $test_relationship_ontology_file =
  $test_util->root_dir() . '/' . $config->{relationship_ontology_path};
my $psi_mod_obo_file = $config->{test_config}->{test_psi_mod_obo_file};

my $synonym_types = $config->{load}->{ontology}->{synonym_types};

my $index_path = $config->data_dir_path('ontology_index_dir');
my $ontology_index = Canto::Track::OntologyIndex->new(config => $config, index_path => $index_path);

$test_util->load_test_ontologies($ontology_index, 1);

@loaded_cvterms = $schema->resultset('Cvterm')->all();

is(@loaded_cvterms, 138);

my $cvprop_rs = $schema->resultset('Cvprop');

my %actual_cv_term_counts = ();

while (defined (my $prop = $cvprop_rs->next())) {
  if ($prop->type()->name() eq 'cv_term_count') {
    $actual_cv_term_counts{$prop->cv()->name()} = $prop->value();
  }
}

my %expected_cv_term_counts = (
  'gene_ontology' => '0',
  'PSI-MOD' => '15',
  'molecular_function' => '8',
  'cellular_component' => '4',
  'relationship' => '0',
  'biological_process' => '9',
  'sequence' => 20,
);

cmp_deeply(\%actual_cv_term_counts,
           \%expected_cv_term_counts);

is(@loaded_cvterms, 138);

my @cvterm_relationships = $schema->resultset('CvtermRelationship')
  ->search({}, { join => { subject => 'cv', type => 'cv' } })->all();

is(@cvterm_relationships, 59);


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


# test lookup in biological_process
my @results =
  $ontology_index->lookup('biological_process', [], 'transmembrane transport', 100);

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


# look for root term
@results = $ontology_index->lookup('biological_process', [], 'biological_process', 100);

is (@results, 1);
my $biological_process_doc = $results[0]->{doc};
is ($biological_process_doc->get('subset_id'), 'is_a__canto_root_subset');

# psi-mod
@results = $ontology_index->lookup('psi-mod', [], 'secondary neutral', 100);

is(@results, 3);

for my $result (@results) {
  my $doc = $result->{doc};
  my $cv_name = $doc->get('cv_name');

  is($cv_name, 'psi_mod');
}

is($results[0]->{doc}->get('term_name'), 'modified residue with a secondary neutral loss');


# molecular_function with synonym
my $synonym_query = 'dihydropteroate pyrophosphorylase activity';
@results = $ontology_index->lookup('molecular_function', [], $synonym_query, 100);

is(@results, 6);

for my $result (@results) {
  my $doc = $result->{doc};
  my $cv_name = $doc->get('cv_name');

  is($cv_name, 'molecular_function');
}

is($results[0]->{doc}->get('text'), 'dihydropteroate synthase activity');
is($results[0]->{doc}->get('term_name'), 'dihydropteroate synthase activity');

@results = $ontology_index->lookup('molecular_function', [],
                                   'dihydropteroate synthetase activity', 100);

is(@results, 6);
is($results[0]->{doc}->get('cv_name'), 'molecular_function');
is($results[0]->{doc}->get('text'), 'dihydropteroate synthase activity');
is($results[0]->{doc}->get('term_name'), 'dihydropteroate synthase activity');


# check loading of alt_ids
my $cvterm_dbxref_rs = $schema->resultset('CvtermDbxref');
is($cvterm_dbxref_rs->count(), 13);

undef $ontology_index;

$ontology_index = Canto::Track::OntologyIndex->new(config => $config, index_path => $index_path);

# try re-loading
$test_util->load_test_ontologies($ontology_index);
is($cvterm_dbxref_rs->count(), 13);

undef $ontology_index;

$ontology_index = Canto::Track::OntologyIndex->new(config => $config, index_path => $index_path);

# test that obsolete terms are loaded but aren't indexed by Lucene
$test_util->load_test_ontologies($ontology_index, 1, 1);
@loaded_cvterms = $schema->resultset('Cvterm')->all();

is(@loaded_cvterms, 164);

ok((grep {
  $_->name() eq 'OBSOLETE FYPO:0002233 viable elongated vegetative cell population'
} @loaded_cvterms), '"viable elongated vegetative cell population" missing');

# test that non-obsolete term is indexed
my $viable = 'viable vegetative cell population';
@results = $ontology_index->lookup('fission_yeast_phenotype', [], $viable, 100);
is(@results, 7);

ok((grep {
  $_->{term_name} eq $viable;
} @results), qq("$viable" missing));


# test that obsolete terms aren't indexed
my $viable_elongated = 'viable elongated vegetative cell population';
@results = $ontology_index->lookup('fission_yeast_phenotype', [], $viable_elongated, 100);
is(@results, 7);

ok(!(grep {
  $_->{term_name} eq $viable_elongated;
} @results), qq("$viable_elongated" shouldn't be returned));

undef $ontology_index;


# check that allow relations are present
@cvterm_relationships = $schema->resultset('CvtermRelationship')
  ->search({}, { join => 'type' })->all();

my %rel_type_cv_counts = ();
my %has_part_rels = ();

for my $rel (@cvterm_relationships) {
  $rel_type_cv_counts{$rel->subject()->cv()->name()}{$rel->type()->name()}++;

  if ($rel->type()->name() eq 'has_part') {
    $has_part_rels{$rel->subject()->name()}{$rel->type()->name()} = $rel->object()->name();
  }
}

cmp_deeply($rel_type_cv_counts{fission_yeast_phenotype},
           {
             'is_a' => 15,
             'has_part' => 2
           });
cmp_deeply($rel_type_cv_counts{sequence},
           {
             'part_of' => 3,
             'is_a' => 18,
             'has_part' => 1
           });
cmp_deeply(\%has_part_rels,
           {
             'elongated multinucleate cell' => {
               'has_part' => 'multinucleate'
             },
             'edited_transcript' => {
               'has_part' => 'anchor_binding_site'
             }
           });
