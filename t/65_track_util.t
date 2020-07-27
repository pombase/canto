use strict;
use warnings;
use Test::More tests => 3;

use Canto::TestUtil;
use Canto::Track::TrackUtil;
use Canto::TrackDB;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');
my $track_schema = $test_util->track_schema();

my $config = $test_util->config();

my $track_util = Canto::Track::TrackUtil->new(config => $config, schema => $track_schema);

my $curs_key = 'aaaa0007';
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

$track_schema = $test_util->track_schema();
my $track_organism = $track_schema->resultset('Organism')->first();
my $track_strain_1 = $track_schema->resultset('Strain')
  ->create({ strain_name => 'track strain name 1', strain_id => 1001,
             organism_id => $track_organism->organism_id() });

my $curs_organism = $curs_schema->resultset('Organism')->first();

my $curs_strain = $curs_schema->resultset('Strain')->create({
  organism_id => $curs_organism->organism_id(),
  track_strain_id => 1001,
});

is($track_schema->resultset('Strain')->count(), 1);

$track_util->delete_unused_strains();

is($track_schema->resultset('Strain')->count(), 1);

$curs_strain->delete();

$track_util->delete_unused_strains();

is($track_schema->resultset('Strain')->count(), 0);
