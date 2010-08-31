#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
  $ENV{"POMCUR_CONFIG_LOCAL_SUFFIX"} = 'test';
  use_ok 'Catalyst::Test', 'PomCur';
}

ok( request('/')->is_success, 'Request should succeed' );
