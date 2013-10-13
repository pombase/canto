use strict;
use warnings;
use Test::More tests => 2;

use Canto::TestUtil;
use Canto::TrackDB;
use Canto::DBLayer::Path;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();
my $schema = Canto::TrackDB->new(config => $config);

my $gene = $schema->find_with_type('Gene',
                                   {
                                     primary_identifier => 'SPBC12C2.02c'
                                   });

my $name_path = Canto::DBLayer::Path->new(path_string => 'primary_name');
is ($name_path->resolve($gene), 'ste20');

my $species_path =
  Canto::DBLayer::Path->new(path_string => 'organism->species');
is ($species_path->resolve($gene), 'pombe');
