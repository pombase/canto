use strict;
use warnings;
use Test::More tests => 1;

use PomCur::Track::TrackStore;


package StoreTest;

use Moose;

has 'config' => (
  is => 'ro',
  isa => 'PomCur::Config'
);

with 'PomCur::Track::TrackStore';

no Moose;


package main;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $store = StoreTest->new(config => $test_util->config());

ok(defined $store->schema());
