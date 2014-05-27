#!/usr/bin/env perl

# copy the ACCEPTED_TIMESTAMP from the session to the curs_curator
# table for old sessions created before curs_curator existed

use strict;
use warnings;

use File::Basename;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use Canto::Track;
use Canto::TrackDB;
use Canto::Meta::Util;
use Canto::Track::CuratorManager;
use Canto::Config;
use Canto::Curs::State;


my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();
my $track_schema = Canto::TrackDB->new(config => $config);

my $curator_manager = Canto::Track::CuratorManager->new(config => $config);

my $state = Canto::Curs::State->new(config => $config);

my $proc = sub {
  my $curs = shift;
  my $curs_schema = shift;
  my $track_schema = shift;

  my ($email, $name, $known_as, $accepted_date,
      $is_admin, $creation_date, $current_curator_id) =
    $curator_manager->current_curator($curs->curs_key());

  if (!defined $current_curator_id) {
    warn 'FAIL: ', $curs->curs_key();
    return;
  }

  my $curs_curator =
    $track_schema->resultset('CursCurator')->find($current_curator_id);

  if (!defined $curs_curator->accepted_date()) {
    my $new_accepted_datestamp =
        $state->get_metadata($curs_schema,
                             Canto::Curs::State::ACCEPTED_TIMESTAMP_KEY());

    $curs_curator->accepted_date($new_accepted_datestamp);
    $curs_curator->update();
  }
};

my @res = Canto::Track::curs_map($config, $track_schema, $proc);
