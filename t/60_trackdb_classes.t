use strict;
use warnings;
use Test::More tests => 3;

use Canto::TestUtil;
use Canto::TrackDB;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();
my $schema = Canto::TrackDB->new(config => $config);

# test getting alt_ids
my $cvterm = $schema->resultset('Cvterm')->find({ name => 'cellular process phenotype' });
ok(defined $cvterm);

my @alt_ids = $cvterm->alt_ids();
is(@alt_ids, 1);
is($alt_ids[0], 'FYPO:0000028');
