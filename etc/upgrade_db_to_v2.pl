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

use PomCur::Config;
use PomCur::Meta::Util;
use PomCur::TrackDB;
use PomCur::DBUtil;

my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}


my $config = PomCur::Config::get_config();
my $track_schema = PomCur::TrackDB->new(config => $config,
                                        disable_foreign_keys => 0);

PomCur::DBUtil::set_db_version($track_schema, 2);

my $dbh = $track_schema->storage()->dbh();
$dbh->do("
ALTER TABLE curs_curator ADD COLUMN creation_date TIMESTAMP;
");
$dbh->do("
ALTER TABLE curs_curator ADD COLUMN accepted_date TIMESTAMP;
");
