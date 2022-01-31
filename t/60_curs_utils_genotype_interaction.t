use strict;
use warnings;
use Test::More tests => 15;
use Test::Deep;
use Clone qw(clone);

use Canto::TestUtil;
use Canto::Curs::Utils;
use Canto::Track::OrganismLookup;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();


my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

my $existing_genotype =
  $curs_schema->find_with_type('Genotype', { identifier => 'aaaa0007-genotype-test-1' });

ok ($existing_genotype);

my $existing_genotype_annotation =
  $existing_genotype->genotype_annotations->first();

ok ($existing_genotype_annotation);

my $unneeded_genotype = $curs_schema->resultset('Genotype')
  ->find({ identifier => 'aaaa0007-genotype-test-2' });

ok ($unneeded_genotype);

my $genotype_annotation_rs =
  $curs_schema->resultset('GenotypeAnnotation');

my $unneeded_genotype_annotation_rs = $genotype_annotation_rs
  ->search({ genotype => $unneeded_genotype->genotype_id() });

map {
  $_->annotation()->delete();
} $unneeded_genotype_annotation_rs->all();

$unneeded_genotype_annotation_rs->reset();
$unneeded_genotype_annotation_rs->delete();

# tidy the test database
$unneeded_genotype->delete();

my $existing_genotype_alleles_rs = $existing_genotype->alleles();

my $ssm4delta_allele = $existing_genotype_alleles_rs->first();

is ($ssm4delta_allele->name(), 'ssm4delta');

my $ssm4delta_genotype = $curs_schema->resultset('Genotype')
  ->create({
    name => 'ssm4delta test genotype',
    identifier => 'ssm4delta-test-genotype-1',
    organism_id => $curs_schema->resultset('Organism')->first()->organism_id(),
  });

$curs_schema->resultset('AlleleGenotype')
  ->create({
    genotype => $ssm4delta_genotype,
    allele => $ssm4delta_allele,
  });

my $other_allele = $existing_genotype_alleles_rs->next();

is ($other_allele->name(), 'SPCC63.05delta');

my $other_genotype = $curs_schema->resultset('Genotype')
  ->create({
    name => 'other allele test genotype',
    identifier => 'other-allele-test-genotype-1',
    organism_id => $curs_schema->resultset('Organism')->first()->organism_id(),
  });

$curs_schema->resultset('AlleleGenotype')
  ->create({
    genotype => $other_genotype,
    allele => $other_allele,
  });

my $deletion_phenotype_data =
  {
    conditions => [
      'green medium',
    ],
    curator => {
      community_curated => 0,
      email => 'some.testperson@testest.org',
      name => 'Some Testperson',
    },
    evidence_code => 'Epitope-tagged protein immunolocalization experiment data',
    term_ontid => 'FYPO:0000013',
  };

my $deletion_phenotype_annotation = $curs_schema->resultset('Annotation')
  ->create({
    status => 'new',
    pub => $curs_schema->resultset('Pub')->first()->pub_id(),
    type => 'phenotype',
    creation_date => '2010-01-02',
    data => '',
  });

$deletion_phenotype_annotation->data($deletion_phenotype_data);
$deletion_phenotype_annotation->update();

my $ssm4delta_genotype_annotation =
  $curs_schema->resultset('GenotypeAnnotation')->create({
    genotype => $ssm4delta_genotype,
    annotation => $deletion_phenotype_annotation,
  });

$curs_schema->resultset('SymmetricGenotypeInteraction')->create({
  interaction_type => 'Synthetic Lethality',
  primary_genotype_annotation_id =>
    $existing_genotype_annotation->genotype_annotation_id(),
  genotype_a_id => $ssm4delta_genotype->genotype_id(),
  genotype_b_id => $other_genotype->genotype_id(),
});

$curs_schema->resultset('DirectionalGenotypeInteraction')->create({
  interaction_type => 'Synthetic Lethality',
  primary_genotype_annotation_id =>
    $existing_genotype_annotation->genotype_annotation_id(),
  genotype_a_id => $other_genotype->genotype_id(),
  genotype_annotation_b_id =>
    $ssm4delta_genotype_annotation->genotype_annotation_id(),
});

my ($completed_count, $annotations_ref) =
  Canto::Curs::Utils::get_annotation_table($config, $curs_schema,
                                           'genotype_interaction');

is (@$annotations_ref, 2);

is ($annotations_ref->[0]->{genotype_a}->{display_name}, 'ssm4delta test genotype');
is ($annotations_ref->[0]->{genotype_b}->{display_name}, 'other allele test genotype');
is ($annotations_ref->[0]->{interaction_type}, 'Synthetic Lethality');

is ($annotations_ref->[1]->{genotype_a}->{display_name}, 'other allele test genotype');
is ($annotations_ref->[1]->{genotype_b}->{display_name}, 'ssm4delta test genotype');
is ($annotations_ref->[1]->{interaction_type}, 'Synthetic Lethality');

my @genotype_b_phenotype_annotations =
  @{$annotations_ref->[1]->{genotype_b_phenotype_annotations}};

is (@genotype_b_phenotype_annotations, 1);

is ($genotype_b_phenotype_annotations[0]->{term_name}, 'T-shaped cells');
is ($genotype_b_phenotype_annotations[0]->{conditions}->[0]->{name}, 'green medium');
