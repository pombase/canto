#!/usr/bin/env perl

use strict;
use warnings;
use Carp;

use Storable qw(thaw);
use MIME::Base64;
use Data::Dumper;

my $sess = shift;

$sess =~ s/\\n/\n/g;

print Dumper([thaw(decode_base64($sess))]), "\n";
