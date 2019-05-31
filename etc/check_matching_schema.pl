#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Basename;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use Canto::Config;
use Canto::Meta::Util;
use Canto::Track;
use Canto::TrackDB;
use Canto::CursDB;
use Canto::DBUtil;
use Canto::Curs::Utils;
use Canto::Curs::GenotypeManager;
use Canto::DBUpgrade;

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}


my $config = Canto::Config::get_config(upgrading => 1);
my $track_schema = Canto::TrackDB->new(config => $config,
                                       disable_foreign_keys => 0);

my $db_version = Canto::DBUtil::get_schema_version($track_schema);
my $code_version = $config->{schema_version};

if ($db_version ne $code_version) {
  warn "Schema mismatch: the database is Canto schema $db_version but the " .
    "code expects version $code_version\n";
  exit (1);
}

