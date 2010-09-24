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
use Data::Rmap ':all';
use Clone qw(clone);

use PomCur::Config;
use PomCur::Meta::Util;
use PomCur::TrackDB;
use PomCur::CursDB;
use PomCur::Curs;

use File::Temp qw(tempdir);

use Moose;

with 'PomCur::Role::MetadataAccess';

no Moose;

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

  my $test_config = LoadFile($test_config_file_name)->{test_config};

  my $app_name = lc PomCur::Config::get_application_name();

  my $config = PomCur::Config->new("$root_dir/$app_name.yaml",
                                   $test_config_file_name);

  my $temp_dir = temp_dir();

  if (!exists $test_config->{test_cases}->{$test_env_type}) {
    die "no test case configured for '$test_env_type'\n";
  }

  $self->{config} = $config;

  my $data_dir = $test_config->{data_dir};

  if ($test_env_type ne 'empty_db') {
    my $track_db_file =
      $test_config->{"track_test_${test_env_type}_db"};

    $config->{track_db_template_file} =
      "$root_dir/$track_db_file";
  }

  my $cwd = getcwd();
  chdir ($root_dir);
  eval {
    PomCur::Meta::Util::initialise_app($config, $temp_dir, 'test');
  };
  chdir $cwd;
  if ($@) {
    die "failed to initialise application: $@\n";
  }

  $config->merge_config("$root_dir/${app_name}_test.yaml");

  my $connect_string = $config->model_connect_string('Track');

  $self->{track_schema} = PomCur::TrackDB->new($config);

  my $db_file_name = connect_string_file_name($connect_string);
  my $test_case_def = $test_config->{test_cases}->{$test_env_type};

  # copy the curs databases too
  if ($test_env_type ne 'empty_db') {
    my @test_case_curs_confs = @$test_case_def;

    for my $test_case_curs_conf (@test_case_curs_confs) {
      my $curs_key = curs_key_of_test_case($test_case_curs_conf);
      my $db_file_name = PomCur::Curs::make_db_file_name($curs_key);

      copy "$data_dir/$db_file_name", $temp_dir or die "$!";
    }
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

=head2

 Usage   : my $test_util = PomCur::TestUtil->new();
           my $root_dir = $test_util->root_dir();
 Function: Return the root directory of the application, ie. the directory
           containing lib, etc, root, t, etc.
 Args    : none

=cut
sub root_dir
{
  my $self = shift;
  return $self->{root_dir};
}

=head2

 Usage   : my $test_util = PomCur::TestUtil->new();
           $test_util->init_test();
           my $config = $test_util->config();
 Function: Return the config object to use while testing
 Args    : none

=cut
sub config
{
  my $self = shift;
  return $self->{config};
}

=head2

 Usage   : my $test_util = PomCur::TestUtil->new();
           $test_util->init_test();
           my $schema = $test_util->track_schema();
 Function: Return the schema object of the test track database
 Args    : none

=cut
sub track_schema
{
  my $self = shift;
  return $self->{track_schema};
}

=head2 temp_dir

 Usage   : my $temp_dir_name = PomCur::TestUtil::temp_dir()
 Function: Create a temporary directory for this test
 Args    : None

=cut
sub temp_dir
{
  (my $test_name = $0) =~ s!.*/(.*)(?:\.t)?!$1!;

  return tempdir("/tmp/pomcur_test_${test_name}_$$.XXXXX", CLEANUP => 1);
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

sub _get_curator_object
{
  my $schema = shift;
  my $email_address = shift;

  return $schema->find_with_type('Person',
                                 { networkaddress => $email_address });
}

sub _get_pub_object
{
  my $schema = shift;
  my $pubmedid = shift;

  return $schema->find_with_type('Pub', { pubmedid => $pubmedid });
}

sub _load_curs_db_data
{
  my $config = shift;
  my $trackdb_schema = shift;
  my $cursdb_schema = shift;
  my $curs_config = shift;

  my $gene_lookup = PomCur::Track::GeneLookup->new(config => $config,
                                                   schema => $trackdb_schema);

  set_metadata($cursdb_schema, 'submitter_email',
               $curs_config->{submitter_email});
  set_metadata($cursdb_schema, 'submitter_name',
               $curs_config->{submitter_name});

  for my $gene_identifier (@{$curs_config->{genes}}) {
    my $result = $gene_lookup->lookup([$gene_identifier]);
    my @found = @{$result->{found}};
    die "Expected 1 result" if @found != 1;
    my $gene_info = $found[0];

    my $new_gene =
      PomCur::Controller::Curs::_create_gene($cursdb_schema, $result);

    my $current_config_gene = $curs_config->{current_gene};
    if ($gene_identifier eq $current_config_gene) {
      set_metadata($cursdb_schema, 'current_gene_id',
                   $new_gene->gene_id());
    }
  }
}

sub _process_data
{
  my $cursdb_schema = shift;
  my $config_data_ref = shift;

  my $data = clone($config_data_ref);

  rmap_to {
    # change 'class_name:field_name' => 'value' to:
    # 'class_name' => object_id
    my %tmp_hash = %$_;
    while (my ($key, $value) = each %tmp_hash) {
      if ($key =~ /(.*):(.*)/) {
        my $class_name = $1;
        my $field_name = $2;
        delete $_->{$key};
        my $type_name = PomCur::DB::table_name_of_class($class_name);
        my $object = $cursdb_schema->find_with_type($class_name,
                                                    {
                                                      $field_name, $value
                                                    });
        $_->{$type_name} = PomCur::DB::id_of_object($object);
      }
    }
  } HASH, $data;

  return $data;
}

=head2 make_curs_db

 Usage   : PomCur::TestUtil::make_curs_db($config, $curs_config,
                                          $trackdb_schema);
 Function: Make a curs database for the given $curs_config and update the
           TrackDB given by $trackdb_schema.  See the test_config.yaml file
           for example curs test case configurations.
 Args    : $config - a PomCur::Config object
           $curs_config - the configuration for this curs
           $trackdb_schema - the TrackDB
 Returns : nothing, dies on error

=cut
sub make_curs_db
{
  my $config = shift;
  my $curs_config = shift;
  my $trackdb_schema = shift;
  my $load_util = shift;

  my $pombe = $load_util->get_organism('Schizosaccharomyces', 'pombe');

  my $test_case_curs_key =
    PomCur::TestUtil::curs_key_of_test_case($curs_config);

  my $create_args = {
    community_curator =>
      _get_curator_object($trackdb_schema, $curs_config->{first_contact_email}),
    curs_key => $test_case_curs_key,
    pub => _get_pub_object($trackdb_schema, $curs_config->{pubmedid}),
  };

  my $curs_object = $trackdb_schema->create_with_type('Curs', $create_args);

  my $curs_file_name =
    PomCur::Curs::make_long_db_file_name($config, $test_case_curs_key);
  unlink $curs_file_name;

  my $cursdb_schema =
    PomCur::Track::create_curs_db($config, $curs_object);

  if (exists $curs_config->{submitter_email}) {
    $cursdb_schema->txn_do(
      sub {
        _load_curs_db_data($config, $trackdb_schema, $cursdb_schema,
                           $curs_config);
      });
  }

}


1;
