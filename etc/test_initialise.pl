#!/usr/bin/perl -w

# script to set up the test database

use strict;
use warnings;
use Carp;

use Text::CSV;
use File::Copy qw(copy);
use File::Temp qw(tempfile);

BEGIN {
  push @INC, "lib";
}

use PomCur::Track;
use PomCur::TrackDB;
use PomCur::Config;
use PomCur::TestUtil;
use PomCur::Track::LoadUtil;
use PomCur::Controller::Curs;

my %test_curators = ();
my %test_publications = ();
my %test_schemas = ();

my $test_util = PomCur::TestUtil->new();

my $config = PomCur::Config->new("pomcur.yaml", "t/test_config.yaml");

$config->{data_directory} = $test_util->root_dir() . '/t/data';


my %test_cases = %{$config->{test_config}->{test_cases}};

sub make_curs_dbs
{
  my $test_case_key = shift;

  my $test_case = $test_cases{$test_case_key};
  my $trackdb_schema = $test_schemas{$test_case_key};
  my $load_util = PomCur::Track::LoadUtil->new(schema => $trackdb_schema);

  return unless defined $test_case;

  my $process_test_case =
    sub {
      for my $curs_config (@$test_case) {
        PomCur::TestUtil::make_curs_db($config, $curs_config, $trackdb_schema,
                                       $load_util);
      }
    };

  eval {
    $trackdb_schema->txn_do($process_test_case);
  };
  if ($@) {
    die "ROLLBACK called: $@\n";
  }
}

my ($fh_with_data, $temp_track_db_with_data) = tempfile();
PomCur::TestUtil::make_base_track_db($config, $temp_track_db_with_data, 1);

my ($fh_no_data, $temp_track_db_no_data) = tempfile();
PomCur::TestUtil::make_base_track_db($config, $temp_track_db_no_data, 0);

for my $test_case_key (sort keys %test_cases) {
  warn "Creating database for $test_case_key\n";
  my $base_track_db;

  if (defined $test_cases{$test_case_key}) {
    $base_track_db = $temp_track_db_with_data;
  } else {
    $base_track_db = $temp_track_db_no_data;
  }

  ($test_schemas{$test_case_key}) =
    PomCur::TestUtil::make_track_test_db($config, $test_case_key, $base_track_db);
  make_curs_dbs($test_case_key);
}

warn "Test initialisation complete\n";
