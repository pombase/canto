use strict;
use warnings;
use Test::More tests => 5;

use PomCur::TestUtil;
use PomCur::TrackDB;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @results = $schema->resultset('Organism')->search();

is(@results, 2);

my $organism = $results[0];

is($organism->taxonid(), 4896);

# test getting alt_ids
my $cvterm = $schema->resultset('Cvterm')->find({ name => 'cellular process phenotype' });
ok(defined $cvterm);

my @alt_ids = $cvterm->alt_ids();
is(@alt_ids, 1);
is($alt_ids[0], 'FYPO:0000028');
