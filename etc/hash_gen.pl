#!/usr/bin/env perl

# generate a password hash suitable for the person table

use strict;
use warnings;

use Digest::SHA qw(sha1_base64);

my $line = <>;

chomp $line;

print sha1_base64($line), "\n";
