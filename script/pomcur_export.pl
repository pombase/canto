#!/usr/bin/env perl -w

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

  push @INC, "lib";
};

use PomCur::Config;
use PomCur::Track;
use PomCur::TrackDB;
use PomCur::Track::Serialise;
use PomCur::Meta::Util;

my $do_help = 0;

my $result = GetOptions ("help|h" => \$do_help);

sub usage
{
  die "usage:
   $0
";
}

if ($do_help) {
  usage();
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

print PomCur::Track::Serialise::json($config, $track_schema), "\n";
