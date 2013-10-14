#!/usr/bin/perl -w

# initialise the external data in the t/data directory

BEGIN {
  push @INC, "lib";
}

use strict;
use warnings;

use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();

$test_util->create_pubmed_test_xml();

