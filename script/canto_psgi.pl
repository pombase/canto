#!/usr/bin/env perl
use strict;

# this script is used for testing, see canto_start instead

BEGIN {
  $ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';
}

use Canto;

use Plack::Builder;

Canto->psgi_app;
