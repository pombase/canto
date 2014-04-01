#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Basename;
use feature qw(switch);

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

my $dbh = $track_schema->storage()->dbh();

given ($new_version) {
  when (3) {
    $dbh->do("
ALTER TABLE person ADD COLUMN known_as TEXT;
");
  }
  when (4) {
    $dbh->do("
UPDATE cvterm SET name = replace(name, 'PomCur', 'Canto');
");
    $dbh->do("
UPDATE cv SET name = replace(name, 'PomCur', 'Canto');
");
  }
  when (5) {
    for my $sql ("PRAGMA foreign_keys = ON;",
                 "ALTER TABLE pub ADD COLUMN community_curatable BOOLEAN DEFAULT false;",
                 "UPDATE pub SET community_curatable = (SELECT pp.value = 'yes' FROM pubprop pp WHERE pub.pub_id = pp.pub_id AND pp.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'community_curatable'));",
                 "DELETE FROM pubprop WHERE type_id IN (SELECT cvterm_id FROM cvterm WHERE name = 'community_curatable');",
                 "DELETE FROM cvterm WHERE name = 'community_curatable';") {
      $dbh->do($sql);
    }
  }
  when (6) {
    use Digest::SHA qw(sha1_base64);

    my $proc = sub {
      my $person_rs = $track_schema->resultset('Person');

      while (defined (my $person = $person_rs->next())) {
        my $current_password = $person->password();
        if (defined $current_password) {
          $person->password(sha1_base64($current_password));
          $person->update();
        }
      }
    };

    $track_schema->txn_do($proc);
  }
  default {
    die "don't know how to upgrade to version $new_version";
  }
}

Canto::DBUtil::set_schema_version($track_schema, $new_version);
