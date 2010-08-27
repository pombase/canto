#!/usr/bin/env perl
use strict;

BEGIN {
  $ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';
}

use PomCur;

use Plack::Builder;

PomCur->setup_engine('PSGI');
my $app = sub { PomCur->run(@_) };

my $type_re = qr!^image/|^application/javascript$|^text/css$!i;

builder {
  enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' }
    "Plack::Middleware::ReverseProxy";
  enable_if { $ENV{POMCUR_DEBUG} }
    "Plack::Middleware::Debug";
  enable 'Expires',
    content_type => $type_re,
    expires => 'access plus 12 months';
  $app;
};
