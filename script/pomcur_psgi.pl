#!/usr/bin/env perl
use strict;
use PomCur;

PomCur->setup_engine('PSGI');
my $app = sub { PomCur->run(@_) };
