#!/usr/bin/perl -w

# (re-)release the application in the virtual machine that runs the PomBase
# installation of the tool

use strict;
use warnings;
use Carp;

use Getopt::Long;

use IO::All;

my $canto_dir = '/var/canto';

my $apps_dir = "$canto_dir/apps";
my $data_dir = "$canto_dir/data";
my $repo = "git://github.com/kimrutherford/canto.git";
my $config_file_name = 'canto_deploy.yaml';

my $start_script = "script/canto_start";

my $google_analytics_id;

GetOptions ("google-analytics-id=s" => \$google_analytics_id);

my $app_name = shift;

die "no application name given\n" unless $app_name;

my $app_data_dir = "$data_dir/${app_name}";

chdir $apps_dir or die "$!";

my $full_app_path = "$apps_dir/$app_name";

if (-d $full_app_path) {
  print "updating $full_app_path\n";
  chdir $full_app_path;
  system "git reset --hard";
  system "git pull --tags origin master";
  print 'now at: ', `git describe --tags`;
} else {
  print "creating $full_app_path\n";
  system "git clone -v $repo $full_app_path";
  chdir $full_app_path;

  if (defined $google_analytics_id) {
    open my $config_file, '>>', $config_file_name
      or die "can't open $config_file_name: $!\n";

    print "google_analytics_id: $google_analytics_id\n";

    close $config_file;
  }
}
