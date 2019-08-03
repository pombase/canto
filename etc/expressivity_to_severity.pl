#!/usr/bin/env perl

# change "has_expressivity" to "has_severity" in extensions

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
use Canto::Config;

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $config = Canto::Config::get_config();
my $track_schema = Canto::TrackDB->new(config => $config);

my $curator_manager = Canto::Track::CuratorManager->new(config => $config);

my $state = Canto::Curs::State->new(config => $config);

my $proc = sub {
  my $curs = shift;
  my $curs_schema = shift;
  my $track_schema = shift;

  warn "processing ", $curs->curs_key(), "\n";

  my $rs = $curs_schema->resultset("Annotation");

  while (defined (my $row = $rs->next())) {
    my $changed = 0;
    my $data = $row->data();
    my $ext_list = $data->{extension};
    if ($ext_list) {
      map {
        my $ext_parts = $_;

        map {
          my $rel = $_->{relation};
          if ($rel && $rel eq "has_expressivity") {
            $_->{relation} = "has_severity";
            $changed = 1;
          }
        } @$ext_parts;
      } @$ext_list;
    }

    if ($changed) {
      $row->data($data);
      $row->update();
    }
  };
};

my @res = Canto::Track::curs_map($config, $track_schema, $proc);


