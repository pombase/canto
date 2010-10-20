use strict;
use warnings;
use Test::More tests => 2;

use PomCur::TestUtil;

use PomCur::Track;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $config = $test_util->config();
my $lookup = PomCur::Track::get_lookup($config, 'go');

my $test_string = 'GO:00040';

package main;

my $c = bless {}, 'MockCatalyst';

my $results = $lookup->web_service_lookup(ontology_name => 'component',
                                          search_string => 'alcohol',
                                          max_results => 10,
                                          include_definition => 1);

ok(defined $results);

ok(grep { $_->{id} eq 'GO:0004022' &&
          $_->{name} eq 'alcohol dehydrogenase (NAD) activity' &&
          defined $_->{definition} &&
          $_->{definition} =~ /Catalysis of the reaction:/i } @$results);

my $child_results =
  $lookup->web_service_lookup(ontology_name => 'component',
                              include_children => 1,
                              search_string => 'GO:0004022',
                              max_results => 10);


