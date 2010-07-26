package PomCur::TestUtil;

=head1 DESCRIPTION

Utility code for testing.

=cut

use strict;
use warnings;
use Carp;
use Cwd qw(abs_path getcwd);
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Basename;
use YAML qw(LoadFile);

use PomCur::Config;
use PomCur::Meta::Util;

=head2

 Usage   : my $utils = PomCur::TestUtil->new($flag);
 Function: set up the test environment, calling new() will create a test
           database and configuration
 Args    : $flag - (optional) pass "empty_db" to set up the tests with an empty
                   tracking database

=cut
sub new
{
  my $class = shift;
  my $arg = shift;

  $ENV{POMCUR_CONFIG_LOCAL_SUFFIX} = 'test';

  my $root_dir = getcwd();

  if (!_check_dir($root_dir)) {
    $root_dir = abs_path("$root_dir/..");
    if (!_check_dir($root_dir)) {
      my $test_name = $ARGV[0];

      $root_dir = abs_path(dirname($test_name) . '/..');

      if (!_check_dir($root_dir)) {
        croak ("can't find project root directory; looked for: etc and lib\n");
      }
    }
  }

  my $use_empty_template_db = 0;

  if (defined $arg){
    if ($arg eq 'empty_db') {
      $use_empty_template_db = 1;
    } else {
      die "unknown argument ($arg) ". __PACKAGE__ . "::new()\n";
    }
  }

  my $test_config_file_name = "$root_dir/t/test_config.yaml";

  my $test_config = LoadFile($test_config_file_name);

  my $scratch_dir =
    "$root_dir/" . $test_config->{test_config}->{scratch_dir};
  my $tracking_scratch_dir =
    "$root_dir/" . $test_config->{test_config}->{tracking_scratch};

  remove_tree($scratch_dir, { error => \my $rm_err } );

  if (@$rm_err) {
    for my $diag (@$rm_err) {
      my ($file, $message) = %$diag;
      warn "error: $message\n";
    }
    exit (1);
  }

  make_path ($tracking_scratch_dir, { error => \my $mk_err });

  if (@$mk_err) {
    for my $diag (@$mk_err) {
      my ($file, $message) = %$diag;
      warn "error: $message\n";
    }
    exit (1);
  }

  my $app_name = lc PomCur::Config::get_application_name();

  my $config = PomCur::Config->new("$root_dir/$app_name.yaml",
                                   $test_config_file_name);

  if (!$use_empty_template_db) {
    $config->{track_db_template_file} =
      "$root_dir/t/data/track_db_test_template.sqlite3";
  }

  my $cwd = getcwd();
  chdir ($root_dir);
  PomCur::Meta::Util::initialise_app($config, $tracking_scratch_dir,
                                     'test');
  chdir $cwd;

  $config->merge_config("$root_dir/${app_name}_test.yaml");

  my $connect_info = $config->{"Model::TrackModel"}->{connect_info}->[0];

  (my $db_file_name = $connect_info) =~ s/dbi:SQLite:dbname=(.*)/$1/;

  my $self = {
    config => $config,
    root_dir => $root_dir,
    track_connect_string => $connect_info,
    track_db_file_name => $db_file_name,
  };

  return bless $self, $class;
}

sub root_dir
{
  my $self = shift;
  return $self->{root_dir};
}

sub config
{
  my $self = shift;
  return $self->{config};
}

sub track_db_file_name
{
  my $self = shift;
  return $self->{track_db_file_name};
}

sub _check_dir
{
  my $dir = shift;
  return -d "$dir/etc" && -d "$dir/lib";
}

1;
