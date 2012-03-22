#!/usr/bin/env perl
use strict;

# this script is used for testing, see pomcur_start instead

BEGIN {
  $ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';
}

use PomCur;

use Plack::Builder;

PomCur->psgi_app;
