package TestUtil;

=head1 DESCRIPTION

Utility code for testing.  use()ing this module will create a test
database in /tmp/

=cut


use strict;
use warnings;
use Carp;
use Cwd qw(abs_path getcwd);
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Basename;

use PomCur::Config;
use PomCur::Meta::Util;

my $_store;

my $_app_name = 'pomcur';

sub import
{
  my $package = shift;
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
    if ($arg eq ':db_empty') {
      $use_empty_template_db = 1;
    } else {
      die "unknown argument ($arg) to import of ". __PACKAGE__ . "\n";
    }
  }

  my $scratch_dir = "$root_dir/t/scratch/";
  my $tracking_scratch_dir = "$scratch_dir/tracking";

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

  my $test_config = "$root_dir/t/test_config.yaml";

  my $config = PomCur::Config->new("$root_dir/$_app_name.yaml", $test_config);

  if (!$use_empty_template_db) {
    $config->{track_db_template_file} =
      "$root_dir/t/data/track_db_test_template.sqlite3";
  }

  $_store = { config => $config,
              root_dir => $root_dir
            };

  my $cwd = getcwd();
  chdir ($root_dir);
  PomCur::Meta::Util::initialise_app($_store->{config}, $tracking_scratch_dir,
                                     'test');
  chdir $cwd;

  $config->merge_config("$root_dir/${_app_name}_test.yaml");
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

1;
