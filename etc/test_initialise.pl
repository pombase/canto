#!/usr/bin/perl -w

# script to set up the test database

use strict;
use warnings;
use Carp;

use utf8;

use Text::CSV;
use File::Copy qw(copy);
use File::Temp qw(tempfile);
use File::Touch;
use Clone;

BEGIN {
  push @INC, "lib";
}

use Canto::Track;
use Canto::TrackDB;
use Canto::Config;
use Canto::TestUtil;
use Canto::Track::LoadUtil;
use Canto::Controller::Curs;


package Canto::Util;

no warnings;

# make sure we have consistent timestamps in the creation_date and
# added_date columns
sub get_current_datetime
{
  return "2012-02-15 13:45:00";
}

1;


package main;

my %test_curators = ();
my %test_publications = ();
my %test_schemas = ();

my $test_config_file = "canto_test.yaml";

touch $test_config_file;

my $test_util = Canto::TestUtil->new();

my $config = Canto::Config->new_test_config();

$config->{data_directory} = $test_util->test_data_dir_full_path();


my %test_cases = %{$config->{test_config}->{test_cases}};

sub make_curs_dbs
{
  my $config = shift;
  my $test_case_key = shift;

  my $test_case = $test_cases{$test_case_key};
  my $trackdb_schema = $test_schemas{$test_case_key};
  my $load_util = Canto::Track::LoadUtil->new(schema => $trackdb_schema);

  return unless defined $test_case;

  my @curs_schemas = ();

  eval {
    for my $curs_config (@$test_case) {
      my ($curs_schema) =
      Canto::TestUtil::make_curs_db($config, $curs_config,
                                     $trackdb_schema, $load_util);
      push @curs_schemas, $curs_schema;
    }
  };
  if ($@) {
    die "ROLLBACK called: $@\n";
  }

  map {
    my $metadata_storer = Canto::Curs::MetadataStorer->new(config => $config);
    $metadata_storer->store_counts($_);
  } @curs_schemas;
}

my ($fh_with_data, $temp_track_db_with_data) = tempfile();
Canto::TestUtil::make_base_track_db($config, $temp_track_db_with_data, 1);

my ($fh_no_data, $temp_track_db_no_data) = tempfile();
Canto::TestUtil::make_base_track_db($config, $temp_track_db_no_data, 0);

for my $test_case_key (sort keys %test_cases) {
  print "Creating database for $test_case_key\n";
  my $base_track_db;

  if (defined $test_cases{$test_case_key}) {
    $base_track_db = $temp_track_db_with_data;
  } else {
    $base_track_db = $temp_track_db_no_data;
  }

  my $dbname;

  ($test_schemas{$test_case_key}, $dbname) =
    Canto::TestUtil::make_track_test_db($config, $test_case_key, $base_track_db);

  my $config_copy = clone $config;

  $config_copy->{'Model::TrackModel'} = {
    schema_class => 'Canto::TrackDB',
    connect_info => [
      "dbi:SQLite:dbname=$dbname"
      ]
    };

  make_curs_dbs($config_copy, $test_case_key);

  Canto::Curs::Utils::store_all_statuses($config_copy, $test_schemas{$test_case_key});
}

print "Test initialisation complete\n";
