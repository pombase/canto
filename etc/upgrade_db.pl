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
use Canto::TrackDB;
use Canto::DBUtil;

if (@ARGV != 1) {
  die "$0: needs one argument - the version to upgrade to\n";
}

my $new_version = shift;

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}


my $config = Canto::Config::get_config();
my $track_schema = Canto::TrackDB->new(config => $config,
                                        disable_foreign_keys => 0);

Canto::DBUtil::set_schema_version($track_schema, $new_version);

my $dbh = $track_schema->storage()->dbh();

if ($new_version == 3) {
  $dbh->do("
ALTER TABLE person ADD COLUMN known_as TEXT;
");
} else {
die "don't know how to upgrade to version $new_version"
}
