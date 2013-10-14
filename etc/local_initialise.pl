#!/usr/bin/perl -w

# create a database in local/ for developer testing

BEGIN {
  push @INC, "lib";
}

use strict;
use warnings;
use Carp;

use Canto::TrackDB;
use Canto::Config;
use Canto::TestUtil;
use Canto::DBUtil;

use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);

use File::Copy::Recursive qw(dircopy);

my $config = Canto::Config->new_test_config();
$config->merge_config("canto_local.yaml");

my $connect_string = $config->model_connect_string('Track');

my $db_file_name =
  Canto::DBUtil::connect_string_file_name($connect_string);

(my $local_dir = $db_file_name) =~ s:(.*?)/.*:$1:;

my $track_test_db =
  Canto::TestUtil::test_track_db_name($config, "curs_annotations_2");

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

my $ontology_index_dir = $config->{ontology_index_dir};
my $ontology_index_path = $config->data_dir_path('ontology_index_dir');

my $test_ontology_index = "$test_data_dir/$ontology_index_dir";

dircopy($test_ontology_index, $ontology_index_path)
  or die "'$!' while copying $test_ontology_index to $ontology_index_path\n";

for my $curs_file (glob ("$test_data_dir/curs*")) {
  copy $curs_file, $local_dir
    or die "'$!' while copying $curs_file\n";;
}
