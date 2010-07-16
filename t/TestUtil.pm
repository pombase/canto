package TestUtil;

=head1 DESCRIPTION

Utility code for testing.  use()ing this module will create a test
database in /tmp/

=cut


use strict;
use warnings;
use Carp;
use Cwd;
use File::Copy;

use PomCur::Config;

my $_store;

sub import
{
  my $root_dir = getcwd();

  if (!_check_dir($root_dir)) {
    $root_dir = abs_path("$root_dir/..");
    if (!_check_dir($root_dir)) {
      croak ("can't find project root directory; looked for: etc and lib\n");
    }
  }

  my $config = PomCur::Config->new("$root_dir/t/test_properties.yaml");

  my $trackdb_conf = $config->{"Model::TrackModel"};

  $_store = { config => $config,
              root_dir => $root_dir,
              trackdb_conf => $trackdb_conf,
            };

  _create_dbs();
}

sub root_dir
{
  return $_store->{root_dir};
}

sub config
{
  return $_store->{config};
}

sub _check_dir
{
  my $dir = shift;
  return -d "$dir/etc" && -d "$dir/lib";
}

sub _create_dbs
{
  my $sqlite_connect_info = $_store->{trackdb_conf}->{connect_info}->[0];

  (my $sqlite_db_file_name = $sqlite_connect_info) =~ s/dbi:SQLite:dbname=(.*)/$1/;

  unlink $sqlite_db_file_name;

  copy ($_store->{config}->{tracking_db_template}, $sqlite_db_file_name);
}

1;
