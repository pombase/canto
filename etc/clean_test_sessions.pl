#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Basename;

use Getopt::Long;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use PomCur::Config;
use PomCur::Meta::Util;
use PomCur::TrackDB;


sub usage
{
  my $message = shift;

  if (defined $message) {
    $message .= "\n";
  } else {
    $message = '';
  }

  die qq|${message}usage:
  $0

Script to remove dead test sessions.
|;
}

if (@ARGV != 0) {
  usage();
}

my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}


my $config = PomCur::Config::get_config();
my $track_schema = PomCur::TrackDB->new(config => $config);

my $iter = PomCur::Track::cursdb_iterator($config, $track_schema);

while (my ($cursdb, $curs_key) = $iter->()) {
}
