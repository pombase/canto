use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;

use Canto::TestUtil;
use Canto::Track::LoadUtil;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $schema = $test_util->track_schema();

my $curs_key = 'aaaa0007';
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $load_util = Canto::Track::LoadUtil->new(schema => $schema);

my $pombe = $load_util->get_organism('Schizosaccharomyces pombe',
                                     4896, 'fission yeast');
$load_util->get_strain($pombe, 'pombe-strain-1');
$load_util->get_strain($pombe, 'pombe-strain-2');

my $strain_rs = $schema->resultset('Strain');
is ($strain_rs->count(), 2);

my @test_orgs = (
  [746128,"Aspergillus fumigatus"],
  [5476,"Candida albicans"],
  [5518,"Fusarium graminearum"],
  [5207,"Cryptococcus neoformans"],
);

for my $org (@test_orgs) {
  $load_util->get_organism($org->[1], $org->[0]);
}

$load_util->load_strains($config, 't/data/pathogen_strains_sample.csv');

$strain_rs = $schema->resultset('Strain');
is ($strain_rs->count(), 25);

my $A1160_strain = $strain_rs->find({ strain_name => 'A1160' });

ok (defined $A1160_strain);

is ($A1160_strain->strainsynonyms()->count(), 2);


my $curs_organism = $curs_schema->resultset('Organism')->first();

$curs_organism->taxonid(746128);
$curs_organism->update();


# test "promoting" a strain from a session into the main track strain table

my $curs_strain_rs = $curs_schema->resultset('Strain');

my $curs_strain = $curs_strain_rs->create({
  organism_id => $curs_organism->organism_id(),
  strain_name => 'A1160',
});

$load_util->load_strains($config, 't/data/pathogen_strains_sample.csv');

$curs_strain = $curs_strain->get_from_storage();


ok (!defined $curs_strain->strain_name());
is ($curs_strain->track_strain_id(), $A1160_strain->strain_id());

# test matching a strain synonym
$curs_strain->strain_name('a1160-b');
$curs_strain->track_strain_id(undef);
$curs_strain->update();

$load_util->load_strains($config, 't/data/pathogen_strains_sample.csv');
$curs_strain = $curs_strain->get_from_storage();

ok (!defined $curs_strain->strain_name());
is ($curs_strain->track_strain_id, $A1160_strain->strain_id());
