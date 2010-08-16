package PomCur::TestUtil;

=head1 DESCRIPTION

Utility code for testing.

=cut

use strict;
use warnings;
use Carp;
use Cwd qw(abs_path getcwd);
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use File::Basename;
use YAML qw(LoadFile);

use PomCur::Config;
use PomCur::Meta::Util;
use PomCur::TrackDB;
use PomCur::CursDB;

use File::Temp qw(tempdir);

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} = 'test';

=head2

 Usage   : my $utils = PomCur::TestUtil->new();
 Function: Create a new TestUtil object
 Args    : none

=cut
sub new
{
  my $class = shift;
  my $arg = shift;

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

  my $self = {
    root_dir => $root_dir,
  };

  return bless $self, $class;
}

=head2

 Usage   : my $file = PomCur::TestUtil::connect_string_file($connect_string);
 Function: Return the db file name from an sqlite connect string
 Args    : $connect_string
 Return  : the file name

=cut
sub connect_string_file_name
{
  my $connect_string = shift;

  (my $db_file_name = $connect_string) =~ s/dbi:SQLite:dbname=(.*)/$1/;

  return $db_file_name;
}

=head2

 Usage   : $test_util->init_test();
 Function: set up the test environment by creating a test database and
           configuration
 Args    : $flag - (optional) pass "empty_db" to set up the tests with an empty
                   tracking database

=cut
sub init_test
{
  my $self = shift;
  my $arg = shift;

  local $ENV{POMCUR_CONFIG_LOCAL_SUFFIX} = 'test';

  my $use_empty_template_db = 0;

  if (defined $arg){
    if ($arg eq 'empty_db') {
      $use_empty_template_db = 1;
    } else {
      die "unknown argument ($arg) ". __PACKAGE__ . "::new()\n";
    }
  }

  my $root_dir = $self->{root_dir};
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

  $self->{config} = $config;

  my $data_dir = $config->{test_config}->{data_dir};

  if (!$use_empty_template_db) {
    $config->{track_db_template_file} =
      "$root_dir/$data_dir/track_db_test_template.sqlite3";
  }

  my $cwd = getcwd();
  chdir ($root_dir);
  eval {
    PomCur::Meta::Util::initialise_app($config, $tracking_scratch_dir,
                                       'test');
  };
  chdir $cwd;
  if ($@) {
    die "failed to initialise application: $@\n";
  }

  $config->merge_config("$root_dir/${app_name}_test.yaml");

  my $connect_string = $config->model_connect_string('Track');

  my $db_file_name = connect_string_file_name($connect_string);

  return (track_db_file_name => $db_file_name);
}

=head2 plack_app

 Function: make a mock Plack application for testing

=cut
sub plack_app
{
  my $self = shift;

  my $psgi_script_name = $self->root_dir() . '/script/pomcur_psgi.pl';
  return Plack::Util::load_psgi($psgi_script_name);
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

sub temp_dir
{
  (my $test_name = $0) =~ s:.*/(.*)\.t:$1:;

  return tempdir("/tmp/pomcur_test_${test_name}_$$.XXXXX", CLEANUP => 0);;
}

sub _check_dir
{
  my $dir = shift;
  return -d "$dir/etc" && -d "$dir/lib";
}

=head2

 Usage   : my $schema = PomCur::TestUtil::schema_for_file($config, $file_name);
 Function: Return a schema object for the given file
 Args    : $config - a PomCur::Config object
           $file_name - the file name of the database
 Return  : the schema

=cut
sub schema_for_file
{
  my $config = shift;
  my $file_name = shift;

  my %config_copy = %$config;

  my $model;

  if ($file_name =~ m:/curs_:) {
    $model = 'Curs';
  } else {
    $model = 'Track';
  }

  %{$config_copy{"Model::${model}Model"}} = (
    schema_class => "PomCur::${model}DB",
    connect_info => ["dbi:SQLite:dbname=$file_name"],
  );

  my $model_class_name = "PomCur::${model}DB";
  my $schema = $model_class_name->new(\%config_copy);
}

=head2

 Usage   : my ($schema, $db_file_name) =
             PomCur::TestUtil::make_track_test_db($config, $key);
 Function: Make a copy of the empty template track database and return a schema
           object for it, or use the supplied file as the template database
 Args    : $config - a PomCur::Config object
           $key - a hash key to use to look up the destination db file name in
                  the test config file
           $track_db_template_file - the file to use as the template (optional)
 Return  : the new schema and the file name of the new database

=cut
sub make_track_test_db
{
  my $config = shift;
  my $test_config_key = shift;
  my $track_db_template_file = shift || $config->{track_db_template_file};

  my $track_test_db_file = $config->{test_config}->{$test_config_key};

  unlink $track_test_db_file;
  copy $track_db_template_file, $track_test_db_file or die "$!\n";

  return (schema_for_file($config, $track_test_db_file), $track_test_db_file);
}

1;
