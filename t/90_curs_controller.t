use strict;
use warnings;
use Test::More tests => 1;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $app = $test_util->plack_app();

my @known_genes = qw(SPCC1739.10 wtf22 SPNCRNA.119);
my @unknown_genes = qw(dummy SPCC999999.99);

test_psgi $app, sub {
  my $cb = shift;


  ok(1);

};

done_testing;
