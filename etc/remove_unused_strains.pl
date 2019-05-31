#!/usr/bin/perl -w

use strict;
use warnings;
use Carp;
use feature ':5.10';

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
use Canto::TrackDB;
use Canto::Track;
use Canto::Track::LoadUtil;
use Canto::Meta::Util;

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();
my $schema = Canto::TrackDB->new(config => $config);

my $track_schema = Canto::TrackDB->new(config => $config);

my %in_use_strain_ids = ();

my $proc = sub {
  my $curs = shift;
  my $curs_schema = shift;
  my $track_schema = shift;

  my $strain_rs = $curs_schema->resultset('Strain');

  while (defined (my $strain = $strain_rs->next())) {
    my $track_strain_id = $strain->track_strain_id();
    if (defined $track_strain_id) {
      $in_use_strain_ids{$track_strain_id} = 1;
    }
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);

my $count = 0;

my $remove_proc = sub {
  my $strain_rs = $track_schema->resultset('Strain');

  while (defined (my $strain = $strain_rs->next())) {
    if (!$in_use_strain_ids{$strain->strain_id()}) {
      $strain->delete();
      $count++;
    }
  }
};

$track_schema->txn_do($remove_proc);

print "Removed $count strains\n";

exit 0;
