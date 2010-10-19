use strict;
use warnings;
use Test::More tests => 2;

use PomCur::Track::OntologyLookup;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $lookup = PomCur::Track::OntologyLookup->new(config => $test_util->config());

ok(defined $lookup->schema());

my $result = $lookup->web_service_lookup(ontology_name => 'function',
                                         search_string => 'alcohol',
                                         max_results => 10,
                                         include_definition => 0,
                                         include_children => 0);

is (@$result, 4);
