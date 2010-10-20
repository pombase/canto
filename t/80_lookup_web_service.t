use strict;
use warnings;
use Test::More tests => 4;

use PomCur::TestUtil;

use PomCur::Track;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $config = $test_util->config();
my $lookup = PomCur::Track::get_lookup($config, 'go');

my $test_string = 'GO:00040';

package main;

my $c = bless {}, 'MockCatalyst';

my $search_string = 'transport';

my $results = $lookup->web_service_lookup(ontology_name => 'component',
                                          search_string => $search_string,
                                          max_results => 10,
                                          include_definition => 1);

ok(defined $results);

is(scalar(@$results), 2);

ok(grep { $_->{id} eq 'GO:0005215' &&
          $_->{name} eq 'transporter activity' &&
          $_->{definition} =~ /^Enables the directed movement of substances/i
        } @$results);

is(scalar(map { $_->{name} =~ /^$search_string/ } @$results), 2);

my $child_results =
  $lookup->web_service_lookup(ontology_name => 'component',
                              include_children => 1,
                              search_string => 'GO:0004022',
                              max_results => 10);
