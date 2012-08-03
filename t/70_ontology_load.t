use strict;
use warnings;
use Test::More tests => 31;

use Data::Compare;

use PomCur::TestUtil;
use PomCur::Track::OntologyLoad;
use PomCur::Track::OntologyIndex;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('empty_db', { copy_ontology_index => 0 });

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @loaded_cvterms = $schema->resultset('Cvterm')->all();

is (@loaded_cvterms, 44);

my $test_go_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_go_obo_file};
my $test_relationship_ontology_file =
  $test_util->root_dir() . '/' . $config->{test_config}->{test_relationship_obo_file};
my $psi_mod_obo_file = $config->{test_config}->{test_psi_mod_obo_file};

my $ontology_index = PomCur::Track::OntologyIndex->new(config => $config);
my $ontology_load = PomCur::Track::OntologyLoad->new(schema => $schema);
my $synonym_types = $config->{load}->{ontology}->{synonym_types};

sub load_all {
  my $include_ro = shift;

  $ontology_index->initialise_index();

  if ($include_ro) {
    $ontology_load->load($test_relationship_ontology_file, undef, $synonym_types);
  }
  $ontology_load->load($test_go_file, $ontology_index, $synonym_types);
  $ontology_load->load($psi_mod_obo_file, $ontology_index, $synonym_types);

  $ontology_index->finish_index();
}

load_all(1);

@loaded_cvterms = $schema->resultset('Cvterm')->all();

is(@loaded_cvterms, 108);

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
my @results =
  $ontology_index->lookup('biological_process', 'transmembrane transport()\:-', 100);

for my $result (@results) {
  my $doc = $result->{doc};
  my $cv_name = $doc->get('cv_name');

  my $cvterm_id = $doc->get('cvterm_id');
  my $cvterm = $schema->find_with_type('Cvterm', $cvterm_id);

  is($cv_name, 'biological_process');
}

is($results[0]->{doc}->get('name'), 'transmembrane transport');
is($results[1]->{doc}->get('name'), 'hydrogen peroxide transmembrane transport');


# psi-mod
@results = $ontology_index->lookup('psi-mod', 'secondary neutral', 100);

is(@results, 3);

for my $result (@results) {
  my $doc = $result->{doc};
  my $cv_name = $doc->get('cv_name');

  is($cv_name, 'psi_mod');
}

is($results[0]->{doc}->get('name'), 'modified residue with a secondary neutral loss');


# molecular_function with synonym
my $long_ugly_synonym =
  '(2-amino-4-hydroxy-7,8-dihydropteridin-6-yl)methyl-diphosphate:4-aminobenzoate ' .
  '2-amino-4-hydroxydihydropteridine-6-methenyltransferase activity';
@results = $ontology_index->lookup('molecular_function',
                                $long_ugly_synonym, 100);

is(@results, 6);

for my $result (@results) {
  my $doc = $result->{doc};
  my $cv_name = $doc->get('cv_name');

  is($cv_name, 'molecular_function');
}

sub _clean
{
  my $str = shift;
  $str =~ s/[^\d\w]/ /g;
  $str =~ s/^\s+//;
  return $str;
}

is($results[0]->{doc}->get('name'), _clean($long_ugly_synonym));

my $ugly_synonym_substring =
  ',8-dihydropteridin-6-yl)methyl-diphosphate:4-aminobenzoate methenyltransferase';
@results = $ontology_index->lookup('molecular_function',
                                   _clean($ugly_synonym_substring), 100);

is(@results, 1);
is($results[0]->{doc}->get('cv_name'), 'molecular_function');
is($results[0]->{doc}->get('name'), _clean($long_ugly_synonym));


# check loading of alt_ids
my $cvterm_dbxref_rs = $schema->resultset('CvtermDbxref');
is($cvterm_dbxref_rs->count(), 33);


# try re-loading
load_all();
is($cvterm_dbxref_rs->count(), 33);
