package PomCur::TestUtil;

=head1 DESCRIPTION

Utility code for testing.

=cut

use strict;
use warnings;
use Carp;
use Cwd qw(abs_path getcwd);
use File::Copy qw(copy);
use File::Copy::Recursive qw(dircopy);
use File::Temp qw(tempdir);
use File::Basename;
use YAML qw(LoadFile);
use Data::Rmap ':all';
use Clone qw(clone);
use XML::Simple;
use IO::All;

use Plack::Test;
use Plack::Util;
use HTTP::Cookies;

use PomCur::Config;
use PomCur::Meta::Util;
use PomCur::TrackDB;
use PomCur::Track;
use PomCur::CursDB;
use PomCur::Curs;
use PomCur::Controller::Curs;
use PomCur::Track::GeneLookup;
use PomCur::Track::CurationLoad;
use PomCur::Track::GeneLoad;
use PomCur::Track::OntologyLoad;
use PomCur::Track::OntologyIndex;
use PomCur::Track::LoadUtil;
use PomCur::Track::PubmedUtil;
use PomCur::DBUtil;

use Moose;

with 'PomCur::Role::MetadataAccess';

no Moose;

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} = 'test';

=head2 new

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

  my $app_name = lc PomCur::Config::get_application_name();
  my $config = PomCur::Config->new("$root_dir/$app_name.yaml");

  my $test_config_file_name = "$root_dir/" . $config->{test_config_file};
  $config->merge_config($test_config_file_name);

  $config->{implementation_classes}->{ontology_annotation_adaptor} =
    'PomCur::Chado::OntologyAnnotationLookup';
  $config->{implementation_classes}->{interaction_annotation_adaptor} =
    'PomCur::Chado::InteractionAnnotationLookup';

  $config->{'Model::ChadoModel'} = {
    schema_class => 'PomCur::ChadoDB',
    connect_info => [
      "dbi:SQLite:dbname=$root_dir/t/data/chado_test_db.sqlite3"
      ]
    };

  $self->{config} = $config;

  return bless $self, $class;
}

=head2 connect_string_file_name

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

=head2 init_test

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
  my $args = shift || {};

  if (!defined $args->{copy_ontology_index}) {
    $args->{copy_ontology_index} = 1;
  }

  local $ENV{POMCUR_CONFIG_LOCAL_SUFFIX} = 'test';

  my $root_dir = $self->{root_dir};
  my $app_name = lc PomCur::Config::get_application_name();
  my $config = $self->{config};

  my $test_config_file_name = "$root_dir/" . $config->{test_config_file};
  my $test_config = LoadFile($test_config_file_name)->{test_config};

  if (!exists $test_config->{test_cases}->{$test_env_type}) {
    die "no test case configured for '$test_env_type'\n";
  }

  my $data_dir = $test_config->{data_dir};

  if ($test_env_type ne 'empty_db') {
    my $track_db_file = test_track_db_name($config, $test_env_type);

    $config->{track_db_template_file} = "$root_dir/$track_db_file";
  }

  my $temp_dir = temp_dir();

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

  $self->{track_schema} = PomCur::TrackDB->new(config => $config);

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

  if ($args->{copy_ontology_index}) {
    my $ontology_index_dir = $config->{ontology_index_dir};
    my $test_ontology_index = "$data_dir/$ontology_index_dir";
    my $dest_ontology_index = "$temp_dir/$ontology_index_dir";

    dircopy($test_ontology_index, $dest_ontology_index)
      or die "'$!' while copying $test_ontology_index to $dest_ontology_index\n";
  }

  return (track_db_file_name => $db_file_name);
}

=head2 plack_app

 Usage   : my $plack_conf = $test_util->plack_app();
           my $app = $plack_conf->{app};
       or: my $plack_conf = $test_util->plack_app(login => $return_path);
           my $app = $plack_conf->{app};
           my $cookie_jar = $plack_conf->{cookie_jar};
 Function: make a mock Plack application for testing
 Args    : login - if passed, preform a login and set the appropriate cookie,
                   then return the cookie_jar (HTTP::Cookies object)

=cut
sub plack_app
{
  my $self = shift;
  my %args = @_;

  my $psgi_script_name = $self->root_dir() . '/script/pomcur_psgi.pl';
  my $app = Plack::Util::load_psgi($psgi_script_name);
  if ($ENV{POMCUR_DEBUG}) {
    $app = Plack::Middleware::Debug->wrap($app);
  }

  my $cookie_jar = HTTP::Cookies->new(
    file => "/tmp/pomcur_web_test_$$.cookies",
    autosave => 1,
  );

  if (defined $args{login}) {
    test_psgi $app, sub {
      my $cb = shift;

      my $uri = new URI('http://localhost:5000/login');
      my $val_email = 'val@sanger.ac.uk';
      my $return_path = $args{login};

      $uri->query_form(email_address => $val_email,
                       password => $val_email,
                       return_path => $return_path);

      my $req = HTTP::Request->new(GET => $uri);
      my $res = $cb->($req);

      my $login_cookie = $res->header('set-cookie');
      $cookie_jar->extract_cookies($res);

      my $expected_return_code = 302;
      if ($res->code != $expected_return_code) {
        die "unexpected return code: got ", $res->code(),
          " instead of $expected_return_code";
      }
      if ($res->header('location') ne $return_path) {
        die "unexpected location returned from login: got ",
          $res->header('location'), " instead of $return_path";

      }
    };
  }

  return {
    app => $app,
    cookie_jar => $cookie_jar,
    test_user_email => 'val@sanger.ac.uk',
  };
}

=head2 root_dir

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

=head2 test_data_dir_full_path

 Usage   : my $test_util = PomCur::TestUtil->new();
           my $root_dir = $test_util->test_data_dir_full_path();
       or:
           my $root_dir =
             $test_util->test_data_dir_full_path('path_bit', $file_name);
 Function: Return the full path to the test data directory, or in the second
           form the full path to a file within the test data directory
 Args    : none

=cut
sub test_data_dir_full_path
{
  my $self = shift;

  my $data_dir = $self->config()->{test_config}->{data_dir};

  if (@_) {
    return $self->root_dir() . "/$data_dir/" . join ('/', @_);
  } else {
    return $self->root_dir() . "/$data_dir";
  }
}

=head2 config

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

=head2 track_schema

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

=head2 test_track_db_name

 Usage   : my $db_file_name =
             PomCur::TestUtil::test_track_db_name($config, $test_name);
 Function: Return the TrackDB database file name for the given test
 Args    : $config - a PomCur::Config object
           $test_name - the name of the test from the test_config.yaml file
 Returns : The db file name

=cut
sub test_track_db_name
{
  my $config = shift;
  my $test_name = shift;

  return $config->{test_config}->{data_dir} .
    "/track_${test_name}_test_template.sqlite3";
}

=head2 make_track_test_db

 Usage   : my ($schema, $db_file_name) =
             PomCur::TestUtil::make_track_test_db($config, $test_name);
 Function: Make a copy of the empty template track database and return a schema
           object for it, or use the supplied file as the template database
 Args    : $config - a PomCur::Config object
           $test_name - the test name used to make the file name
           $track_db_template_file - the file to use as the template (optional)
 Return  : the new schema and the file name of the new database

=cut
sub make_track_test_db
{
  my $config = shift;
  my $test_name = shift;
  my $track_db_template_file = shift || $config->{track_db_template_file};

  my $track_test_db_file = test_track_db_name($config, $test_name);

  unlink $track_test_db_file;
  copy $track_db_template_file, $track_test_db_file or die "$!\n";

  return (PomCur::DBUtil::schema_for_file($config, $track_test_db_file,
                                          'Track'),
          $track_test_db_file);
}


# pubmed IDs of publications for which we will load all data from pubmed:
my @test_pub_ids = (
  7958849, 19351719, 17304215, 19686603, 19160458, 19664060, 19041767,
  19037101, 19436749, 7518718, 18430926, 19056896, 18426916, 20976105,
  20622008, 19756689, 16641370, 20870879, 18556659, 19211838, 19627505,
  10467002
);

=head2 create_pubmed_test_xml

 Usage   : PomCur::TestUtil::create_pubmed_test_xml();
 Function: Create a test file for PubMed code tests by downloading XML from
           PubMed
 Args    : none
 Returns : none

=cut
sub create_pubmed_test_xml
{
  my $self = shift;

  my $config = PomCur::Config->get_config();

  my $xml = PomCur::Track::PubmedUtil::get_pubmed_xml_by_ids($config,
                                                             @test_pub_ids);

  my $pubmed_xml_file = $self->publications_xml_file();

  open my $pubmed_xml_fh, '>', $pubmed_xml_file
    or die "can't open $pubmed_xml_file for writing: $!\n";

  print $pubmed_xml_fh $xml;

  close $pubmed_xml_fh or die "$!";
}

=head2 get_pubmed_test_xml

 Usage   : my $xml = get_pubmed_test_xml();
 Function: Return the contents of the test XML file.  The file is updated with
           the etc/data_initialise.pl script
 Args    : none
 Returns : the XML

=cut
sub get_pubmed_test_xml
{
  my $self = shift;

  my $xml_file_name = $self->publications_xml_file();

  return IO::All->new($xml_file_name)->slurp();
}

# pubmed IDs which won't have title, authors, etc.
my @extra_test_pubs = (20976105, 20622008);

sub _load_extra_pubs
{
  my $schema = shift;

  my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);

  map {
    my $uniquename = $PomCur::Track::PubmedUtil::PUBMED_PREFIX . ":$_";
    $load_util->get_pub($uniquename, 'admin_load');
  } @extra_test_pubs;
}

sub _add_pub_details
{
  my $config = shift;
  my $schema = shift;

  my $test_config = $config->{test_config};
  my $data_dir = $test_config->{data_dir};
  my $xml_file_name = $test_config->{test_pubmed_xml};

  my $full_file_name = $data_dir . '/'. $xml_file_name;
  my $xml = IO::All->new($full_file_name)->slurp();
  PomCur::Track::PubmedUtil::load_pubmed_xml($schema, $xml, 'admin_load');
}

=head2 make_base_track_db

 Usage   : my $schema =
             PomCur::TestUtil::make_base_track_db($config, $db_file_name);
 Function: Create a TrackDB for testing with basic data: curation data, sample
           genes and publication information
 Args    : $config - a PomCur::Config object (including the test properties)
           $db_file_name - the file to create
           $load_data - if non-zero or undef, load sample data into the new
                        database, otherwise just load the schema
 Returns : The TrackDB schema

=cut
sub make_base_track_db
{
  my $config = shift;
  my $db_file_name = shift;
  my $load_data = shift;

  if (!defined $load_data) {
    $load_data = 1;
  }

  my $curation_file = $config->{test_config}->{curation_spreadsheet};
  my $genes_file = $config->{test_config}->{test_genes_file};
  my $genes_file_organism_2 =
    $config->{test_config}->{test_genes_file_organism_2};
  my $go_obo_file = $config->{test_config}->{test_go_obo_file};
  my $phenotype_obo_file = $config->{test_config}->{test_phenotype_obo_file};
  my $psi_mod_obo_file = $config->{test_config}->{test_psi_mod_obo_file};
  my $relationship_obo_file =
    $config->{test_config}->{test_relationship_obo_file};

  my $track_db_template_file = $config->{track_db_template_file};

  unlink $db_file_name;
  copy $track_db_template_file, $db_file_name or die "$!\n";

  my $schema = PomCur::DBUtil::schema_for_file($config, $db_file_name, 'Track');
  my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);

  if ($load_data) {
    my ($organism, $organism_2) = add_test_organisms($config, $schema);

    my $curation_load = PomCur::Track::CurationLoad->new(schema => $schema);
    my $gene_load = PomCur::Track::GeneLoad->new(schema => $schema,
                                                 organism => $organism);
    my $gene_load_organism_2 =
      PomCur::Track::GeneLoad->new(schema => $schema,
                                   organism => $organism_2);

    my $ontology_index = PomCur::Track::OntologyIndex->new(config => $config);
    $ontology_index->initialise_index();
    my $ontology_load = PomCur::Track::OntologyLoad->new(schema => $schema);

    my $synonym_types = $config->{load}->{ontology}->{synonym_types};

    my $process =
      sub {
        $curation_load->load($curation_file);
        _load_extra_pubs($schema);
        _add_pub_details($config, $schema);

        open my $genes_fh, '<', $genes_file or die "can't open $genes_file: $!";
        $gene_load->load($genes_fh);
        close $genes_fh or die "can't close $genes_file: $!";

        open $genes_fh, '<', $genes_file_organism_2 or die "can't open $genes_file_organism_2: $!";
        $gene_load_organism_2->load($genes_fh);
        close $genes_fh or die "can't close $genes_file_organism_2: $!";

        $ontology_load->load($relationship_obo_file, undef, $synonym_types);
        $ontology_load->load($go_obo_file, $ontology_index, $synonym_types);
        $ontology_load->load($phenotype_obo_file, $ontology_index,
                             $synonym_types);
        $ontology_load->load($psi_mod_obo_file, $ontology_index,
                             $synonym_types);
      };

    $schema->txn_do($process);

    $ontology_index->finish_index();
  }

  return $schema;
}

=head2 add_test_organisms

 Usage   : my @orgs = PomCur::TestUtil::add_test_organisms($config, $schema);
 Function: Create the test organisms
 Args    : $config - a PomCur::Config object
           $schema - the TrackDB schema object
 Returns : a list of the new Organism objects

=cut
sub add_test_organisms
{
  my $config = shift;
  my $schema = shift;

  my @ret = ();

  my $test_config = $config->{test_config};
  my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);

  for my $org_conf (@{$test_config->{organisms}}) {
    push @ret, $load_util->get_organism($org_conf->{genus},
                                        $org_conf->{species},
                                        $org_conf->{taxonid});

  }

  return @ret;
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
                                 { email_address => $email_address });
}

sub _get_pub_object
{
  my $schema = shift;
  my $uniquename = shift;

  return $schema->find_with_type('Pub', { uniquename => $uniquename });
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
    if (@found != 1) {
      die "Expected 1 result for $gene_identifier not ", scalar(@found)
    }
    my $gene_info = $found[0];

    my $new_gene =
      PomCur::Controller::Curs::_create_genes($cursdb_schema, $result);

    my $current_config_gene = $curs_config->{current_gene};
    if ($gene_identifier eq $current_config_gene) {
      set_metadata($cursdb_schema, 'current_gene_id',
                   $new_gene->gene_id());
    }
  }

  for my $annotation (@{$curs_config->{annotations}}) {
    my %create_args = %{_process_data($cursdb_schema, $annotation)};

    $create_args{creation_date} = '2010-01-02';

    # save the args that are arrays and set them after creation to cope with
    # many-many relations
    my %array_args = ();

    for my $key (keys %create_args) {
      if (ref $create_args{$key} eq 'ARRAY') {
        $array_args{$key} = $create_args{$key};
        delete $create_args{$key};
      }
    }

    my $new_annotation =
      $cursdb_schema->create_with_type('Annotation', { %create_args });

    for my $key (keys %array_args) {
      my $method = "set_$key";
      $new_annotation->$method(@{$array_args{$key}});
    }
  }
}

sub _replace_object
{
  my $schema = shift;
  my $class_name = shift;
  my $lookup_field_name = shift;
  my $value = shift;
  my $return_object = shift;

  my $object = $schema->find_with_type($class_name,
                                       {
                                         $lookup_field_name, $value
                                       });

  if ($return_object) {
    return $object;
  } else {
    return PomCur::DB::id_of_object($object);
  }
}

sub _process_data
{
  my $cursdb_schema = shift;
  my $config_data_ref = shift;

  my $data = clone($config_data_ref);

  my $field_name = $1;
  my $class_name = $2;
  my $lookup_field_name = $3;

  rmap_to {
    # change 'field_name(class_name:field_name)' => [value, value] to:
    # 'field_name' => [object_id, object_id] by looking up the object
    my %tmp_hash = %$_;
    while (my ($key, $value) = each %tmp_hash) {
      if ($key =~ /([^:]+)\((.*):(.*)\)/) {
        my $field_name = $1;
        my $class_name = $2;
        my $lookup_field_name = $3;
        delete $_->{$key};
        my $type_name = PomCur::DB::table_name_of_class($class_name);

        if (ref $value eq 'ARRAY') {
          $_->{$field_name} = [map {
            _replace_object($cursdb_schema, $class_name,
                            $lookup_field_name, $_, 1);
          } @$value];
        } else {
          $_->{$field_name} =
            _replace_object($cursdb_schema,
                            $class_name, $lookup_field_name, $value);
        }
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
 Args    : $config - a PomCur::Config object that includes the test properties
           $curs_config - the configuration for this curs
           $trackdb_schema - the TrackDB
 Returns : ($curs_schema, $cursdb_file_name) - A CursDB object for the new db,
           and its file name - die()s on failure

=cut
sub make_curs_db
{
  my $config = shift;
  my $curs_config = shift;
  my $trackdb_schema = shift;
  my $load_util = shift;

  my $test_case_curs_key =
    PomCur::TestUtil::curs_key_of_test_case($curs_config);

  my $create_args = {
    assigned_curator =>
      _get_curator_object($trackdb_schema, $curs_config->{first_contact_email}),
    curs_key => $test_case_curs_key,
    pub => _get_pub_object($trackdb_schema, $curs_config->{uniquename}),
  };

  my $curs_object = $trackdb_schema->create_with_type('Curs', $create_args);

  my $curs_file_name =
    PomCur::Curs::make_long_db_file_name($config, $test_case_curs_key);
  unlink $curs_file_name;

  my ($cursdb_schema, $cursdb_file_name) =
    PomCur::Track::create_curs_db($config, $curs_object);

  if (exists $curs_config->{submitter_email}) {
    $cursdb_schema->txn_do(
      sub {
        _load_curs_db_data($config, $trackdb_schema, $cursdb_schema,
                           $curs_config);
      });
  }

  return ($cursdb_schema, $cursdb_file_name);
}

=head2 publications_xml_file

 Usage   : my $xml_filename = PomCur::TestUtil::publications_xml_file
 Function: return the name of the test data file of XML from PubMed
 Args    : none

=cut
sub publications_xml_file
{
  my $self = shift;

  return $self->root_dir() . '/t/data/entrez_pubmed.xml';
}


1;
