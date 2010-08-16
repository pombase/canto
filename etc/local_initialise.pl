#!/usr/bin/perl -w

# create a database in local/ for developer testing

BEGIN {
  push @INC, "lib";
}

use strict;
use warnings;
use Carp;

use PomCur::TrackDB;
use PomCur::Config;
use PomCur::TestUtil;

use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);

my $config = PomCur::Config->new("pomcur.yaml", "t/test_config.yaml",
                                 "pomcur_local.yaml");

my $connect_string = $config->model_connect_string('Track');

my $db_file_name =
  PomCur::TestUtil::connect_string_file_name($connect_string);

(my $local_dir = $db_file_name) =~ s:(.*?)/.*:$1:;

my $track_test_db = $config->{test_config}->{track_test_3_curs_db};

(my $test_data_dir = $track_test_db) =~ s:(.*)/.*:$1:;

remove_tree($local_dir, { error => \my $rm_err } );

if (@$rm_err) {
  for my $diag (@$rm_err) {
    my ($file, $message) = %$diag;
    warn "error: $message\n";
  }
  exit (1);
}

make_path ($local_dir, { error => \my $mk_err });

if (@$mk_err) {
  for my $diag (@$mk_err) {
    my ($file, $message) = %$diag;
    warn "error: $message\n";
  }
  exit (1);
}

copy $track_test_db, $db_file_name
  or die "'$!' while creating $db_file_name\n";;

system ("cp $test_data_dir/curs* $local_dir/");
