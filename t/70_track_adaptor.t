use strict;
use warnings;
use Test::More tests => 1;


package LookupTest;

use Moose;

has 'config' => (
  is => 'ro',
  isa => 'Canto::Config'
);

with 'Canto::Track::TrackAdaptor';

no Moose;


package main;

use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $lookup = LookupTest->new(config => $test_util->config());

ok(defined $lookup->schema());
