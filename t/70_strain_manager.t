use strict;
use warnings;
use Try::Tiny;
use Test::More tests => 29;
use Test::Deep;

use Canto::TestUtil;
use Canto::Track::OrganismLookup;
use Canto::Track::StrainLookup;
use Canto::Curs::StrainManager;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = Canto::TrackDB->new(config => $config);
my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

my $track_organism = $track_schema->resultset('Organism')->first();

my $track_strain_1 = $track_schema->resultset('Strain')
  ->create({ strain_name => 'track strain name 1', strain_id => 1001,
             organism_id => $track_organism->organism_id() });
$track_schema->resultset('Strainsynonym')
  ->create({ strain => $track_strain_1, synonym => 'track_strain_1_syn' });

my $curs_organism = $track_schema->resultset('Organism')->first();
$curs_schema->resultset('Strain')
  ->create({ strain_name => 'curs strain',
             organism_id => $curs_organism->organism_id() });
$curs_schema->resultset('Strain')
  ->create({ track_strain_id => 1001,
             organism_id => $curs_organism->organism_id() });

my $organism_lookup = Canto::Track::OrganismLookup->new(config => $test_util->config());
my $strain_lookup = Canto::Track::StrainLookup->new(config => $test_util->config());

my $strain_manager =
  Canto::Curs::StrainManager->new(curs_schema => $curs_schema,
                                  config => $config,
                                  organism_lookup => $organism_lookup);

try {
  $strain_manager->delete_strain_by_id(321);
  fail("expected an error");
} catch {
  pass("expected deletion error");
};


my @strains_in_track = $strain_lookup->lookup_by_strain_ids(1001);

is($strains_in_track[0]->{strain_name}, 'track strain name 1');


my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $curs_schema,
                                                   config => $config);

my $strain_res = $service_utils->list_for_service('strain');

is(@$strain_res, 2);

cmp_deeply($strain_res,
           [
             {
               'taxon_id' => 4896,
               'strain_name' => 'curs strain'
             },
             {
               'strain_id' => 1001,
               'taxon_id' => 4896,
               'strain_name' => 'track strain name 1',
               'synonyms' => ['track_strain_1_syn'],
             }
           ]);


my $deleted_strain = $strain_manager->delete_strain_by_id(1001);

is ($deleted_strain->track_strain_id(), 1001);

$strain_res = $service_utils->list_for_service('strain');
is(@$strain_res, 1);
cmp_deeply($strain_res,
           [
             {
               'taxon_id' => 4896,
               'strain_name' => 'curs strain'
             },
           ]);

$deleted_strain = $strain_manager->delete_strain_by_name(4896, 'curs strain');

$strain_res = $service_utils->list_for_service('strain');
is(@$strain_res, 0);


my $added_strain = $strain_manager->add_strain_by_id(1001);

is ($added_strain->track_strain_id(), 1001);

$strain_res = $service_utils->list_for_service('strain');
is(@$strain_res, 1);
cmp_deeply($strain_res,
           [
             {
               'strain_id' => 1001,
               'taxon_id' => 4896,
               'strain_name' => 'track strain name 1',
               'synonyms' => ['track_strain_1_syn'],
             },
           ]);


$strain_manager->delete_strain_by_id(1001);

$strain_res = $service_utils->list_for_service('strain');
is(@$strain_res, 0);
cmp_deeply($strain_res, []);


$added_strain = $strain_manager->add_strain_by_name(4896, 'track strain name 1');

is ($added_strain->track_strain_id(), 1001);


$strain_res = $service_utils->list_for_service('strain');
is(@$strain_res, 1);
cmp_deeply($strain_res,
           [
             {
               'strain_id' => 1001,
               'taxon_id' => 4896,
               'strain_name' => 'track strain name 1',
               'synonyms' => ['track_strain_1_syn'],
             },
           ]);



$added_strain = $strain_manager->add_strain_by_name(4896, 'other strain name 1');

is ($added_strain->track_strain_id(), undef);
is ($added_strain->strain_name(), 'other strain name 1');


$strain_res = $service_utils->list_for_service('strain');
is(@$strain_res, 2);

cmp_deeply($strain_res,
           [
             {
               'taxon_id' => 4896,
               'strain_name' => 'other strain name 1',
             },
             {
               'strain_id' => 1001,
               'taxon_id' => 4896,
               'strain_name' => 'track strain name 1',
               'synonyms' => ['track_strain_1_syn'],
             },
           ]);


my $strain_by_name = $strain_manager->find_strain_by_name(4896, 'NO SUCH STRAIN');
ok (!defined $strain_by_name);

$strain_by_name = $strain_manager->find_strain_by_name(4896, 'other strain name 1');
is ($strain_by_name->strain_name(), 'other strain name 1');

$strain_by_name = $strain_manager->find_strain_by_name(4896, 'track strain name 1');
is ($strain_by_name->strain_name(), undef);


$deleted_strain = $strain_manager->delete_strain_by_name(4896, 'other strain name 1');

is ($deleted_strain->strain_name(), 'other strain name 1');

$strain_res = $service_utils->list_for_service('strain');
is(@$strain_res, 1);

cmp_deeply($strain_res,
           [
             {
               'strain_id' => 1001,
               'taxon_id' => 4896,
               'strain_name' => 'track strain name 1',
               'synonyms' => ['track_strain_1_syn'],
             },
           ]);

$strain_manager->add_strain_by_name(4896, 'other strain name 1');
$strain_manager->add_strain_by_name(4932, 'cerevisiae strain 1');

$strain_res = $service_utils->list_for_service('strain');
is(@$strain_res, 3);

$strain_manager->delete_strains_by_taxon_id(4896);

$strain_res = $service_utils->list_for_service('strain');
is(@$strain_res, 1);

$strain_manager->delete_strains_by_taxon_id(4932);

$strain_res = $service_utils->list_for_service('strain');
is(@$strain_res, 0);
