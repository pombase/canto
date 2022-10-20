#!/usr/bin/env perl

# example script for change a extension relation name
# See: https://github.com/pombase/canto/issues/2345

use strict;
use warnings;
use Carp;

use File::Basename;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    chdir "..";
  }
};

use lib qw(lib);

use Canto::Config;
use Canto::TrackDB;
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


my $old_ext_rel_name = 'has_regulation_target';
my $new_ext_rel_name = 'has_input';

my $proc = sub {
  my $curs = shift;
  my $cursdb = shift;

  my $annotation_rs = $cursdb->resultset('Annotation');

  while (defined (my $annotation = $annotation_rs->next())) {

    my $data = $annotation->data();

    my $changed = 0;

    my $extension = $data->{extension};

    if (defined $extension) {

        map {
          my $or_part = $_;
          map {
            my $and_part = $_;

            if ((1 || !$and_part->{rangeType} ||
                 $and_part->{rangeType} && $and_part->{rangeType} eq 'Ontology') &&
                $and_part->{relation} eq $old_ext_rel_name ) {
              $and_part->{relation} = $new_ext_rel_name;
              warn "changed annotation in ", $curs->curs_key(), "\n";
              $changed = 1;
            }
          } @$or_part;
        } @$extension;
    }

    if ($changed) {
      $annotation->data($data);
      $annotation->update();
    }
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);
