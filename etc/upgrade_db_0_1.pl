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
use PomCur::Track;
use PomCur::Track::CuratorManager;
use PomCur::Role::MetadataAccess;

my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}


my $config = PomCur::Config::get_config();
my $track_schema = PomCur::TrackDB->new(config => $config);

my $schema_version_rs =
  $track_schema->resultset('Metadata')
               ->search({ 'type.name' => 'schema_version' },
                        { join => 'type' });
my $current_db_version = $schema_version_rs->first()->value();

if ($current_db_version == 0) {
  my $schema_version_row = $schema_version_rs->first();
  $schema_version_row->value(1);
  $schema_version_row->update();
} else {
  die "can't upgrade schema_version: $current_db_version\n";
}

my $dbh = $track_schema->storage()->dbh();
$dbh->do("
CREATE TABLE curs_curator (
       curs_curator_id integer NOT NULL PRIMARY KEY,
       curs integer REFERENCES curs(curs_id) NOT NULL,
       curator integer REFERENCES person(person_id) NOT NULL
);
");

my $iter = PomCur::Track::curs_iterator($config, $track_schema);

my $curator_manager =
  PomCur::Track::CuratorManager->new(config => $config);

while (my ($curs, $cursdb) = $iter->()) {
  warn "upgrading: ", $curs->curs_key(), "\n";
  my $submitter_email =
    PomCur::Role::MetadataAccess->get_metadata($cursdb, 'submitter_email');
  PomCur::Role::MetadataAccess->unset_metadata($cursdb, 'submitter_email');
  my $submitter_name =
    PomCur::Role::MetadataAccess->get_metadata($cursdb, 'submitter_name');
  PomCur::Role::MetadataAccess->unset_metadata($cursdb, 'submitter_name');

  if (!defined $submitter_email) {
    die if defined $submitter_name;

    warn "skipping - no email\n";
    next;
  }

  if (!defined $submitter_name) {
    die;
  }

  $curator_manager->set_curator($curs->curs_key(), $submitter_email,
                                $submitter_name);
}

