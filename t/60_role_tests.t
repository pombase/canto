use strict;
use warnings;
use Test::More tests => 2;

use MooseX::Test::Role;

use Canto::TestUtil;
use Canto::TrackDB;
use Canto::Role::TaxonIDLookup;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();
my $schema = Canto::TrackDB->new(config => $config);

my @results = $schema->resultset('Organism')->search();

is(@results, 2);

my $organism = $results[0];

my $taxonidlookup = consumer_of('Canto::Role::TaxonIDLookup',
                                  config => sub {
                                    return $config;
                                  });



is($taxonidlookup->taxon_id_lookup($organism), 4896);
