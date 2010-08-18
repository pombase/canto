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
use PomCur::Curs;

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
 Args    : $arg - pass "empty_db" to set up the tests with an empty
                  tracking database
                - pass "1_curs" to get a tracking database with one curation
                  session (initialises the curs database too)
                - pass "3_curs" to set up 3 curation sessions
                - pass nothing or "default" to set up a tracking database
                  populated with test data, but with no curation sessions

=cut
sub init_test
{
  my $self = shift;
  my $test_env_type = shift || '0_curs';

  local $ENV{POMCUR_CONFIG_LOCAL_SUFFIX} = 'test';

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

  if ($test_env_type ne 'empty_db') {
    my $track_db_file =
      $config->{test_config}->{"track_test_${test_env_type}_db"};

    $config->{track_db_template_file} =
      "$root_dir/$track_db_file";
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

  $self->{track_schema} = PomCur::TrackDB->new($config);

  my $db_file_name = connect_string_file_name($connect_string);
  my $test_case_def = $config->{test_config}->{test_cases}->{$test_env_type};
  my @test_case_curs_confs = @$test_case_def;

  for my $test_case_curs_conf (@test_case_curs_confs) {
    my $curs_key = curs_key_of_test_case($test_case_curs_conf);
    my $db_file_name = PomCur::Curs::make_db_file_name($curs_key);

    copy "$data_dir/$db_file_name", $tracking_scratch_dir or die "$!";
  }

  return (track_db_file_name => $db_file_name);
}

=head2 plack_app

 Function: make a mock Plack application for testing

=cut
sub plack_app
{
  my $self = shift;

  my $psgi_script_name = $self->root_dir() . '/script/pomcur_psgi.pl';
  my $app = Plack::Util::load_psgi($psgi_script_name);
  if ($ENV{POMCUR_DEBUG}) {
    $app = Plack::Middleware::Debug->wrap($app);
  }
  return $app;
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

sub track_schema
{
  my $self = shift;
  return $self->{track_schema};
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

=head2 curs_key_of_test_case

 Usage   : my $curs_key = PomCur::TestUtil::curs_key_of_test_case($test_case);
 Function: Get the curs_key to use for the given curs test case definition
 Args    : $test_case - the test case definition
 Return  :

=cut
sub curs_key_of_test_case
{
  my $test_case_def = shift;

  return $test_case_def->{curs_key};
}

1;
