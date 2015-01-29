package Canto::TestUtil;

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
use HTTP::Request::Common;

use Canto::Config;
use Canto::Meta::Util;
use Canto::TrackDB;
use Canto::Track;
use Canto::CursDB;
use Canto::Curs;
use Canto::Controller::Curs;
use Canto::Track::GeneLookup;
use Canto::Track::CurationLoad;
use Canto::Track::GeneLoad;
use Canto::Track::AlleleLoad;
use Canto::Track::OntologyLoad;
use Canto::Track::OntologyIndex;
use Canto::Track::LoadUtil;
use Canto::Track::PubmedUtil;
use Canto::Track::CuratorManager;
use Canto::DBUtil;

use Moose;

with 'Canto::Role::MetadataAccess';

has curator_manager => (is => 'rw', init_arg => undef,
                        isa => 'Canto::Track::CuratorManager');

no Moose;

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} = 'test';

=head2 new

 Usage   : my $utils = Canto::TestUtil->new();
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

  my $app_name = lc Canto::Config::get_application_name();
  my $config = Canto::Config->new("$root_dir/$app_name.yaml");

  my $test_config_file_name = "$root_dir/" . $config->{test_config_file};
  $config->merge_config($test_config_file_name);

  $config->{implementation_classes}->{ontology_annotation_adaptor} =
    'Canto::Chado::OntologyAnnotationLookup';
  $config->{implementation_classes}->{interaction_annotation_adaptor} =
    'Canto::Chado::InteractionAnnotationLookup';

  $self->{config} = $config;

  bless $self, $class;

  $self->curator_manager(Canto::Track::CuratorManager->new(config => $config));

  return $self;
}

=head2 init_test

 Usage   : $test_util->init_test();
 Function: set up the test environment by creating a test database and
           configuration
           also sets $::test_mode to 1
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

  local $ENV{CANTO_CONFIG_LOCAL_SUFFIX} = 'test';

  $Canto::access_control_enabled = 0;

  my $root_dir = $self->{root_dir};
  my $app_name = lc Canto::Config::get_application_name();
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
    Canto::Meta::Util::initialise_app($config, $temp_dir, 'test');
  };
  chdir $cwd;
  if ($@) {
    die "failed to initialise application: $@\n";
  }

  $config->merge_config("$root_dir/${app_name}_test.yaml");

  my $connect_string = $config->model_connect_string('Track');

  $self->{track_schema} = Canto::TrackDB->new(config => $config);

  my $db_file_name = Canto::DBUtil::connect_string_file_name($connect_string);
  my $test_case_def = $test_config->{test_cases}->{$test_env_type};

  # copy the curs databases too
  if ($test_env_type ne 'empty_db') {
    my @test_case_curs_confs = @$test_case_def;

    for my $test_case_curs_conf (@test_case_curs_confs) {
      my $curs_key = curs_key_of_test_case($test_case_curs_conf);
      my $db_file_name = Canto::Curs::make_db_file_name($curs_key);

      copy "$data_dir/$db_file_name", $temp_dir or die "$!";
    }
  }

  my $chado_test_db_file = $test_config->{test_chado_db};
  copy "$data_dir/$chado_test_db_file", $temp_dir or die "$!";
  my $test_chado_db_copy ="$temp_dir/$chado_test_db_file";
  $self->{chado_schema} =
    Canto::DBUtil::schema_for_file($config, $test_chado_db_copy,
                                    'Chado');
  $config->{'Model::ChadoModel'} = {
    schema_class => 'Canto::ChadoDB',
    connect_info => [
      "dbi:SQLite:dbname=$test_chado_db_copy",
    ],
  };

  if ($args->{copy_ontology_index}) {
    my $ontology_index_dir = $config->{ontology_index_dir};
    my $test_ontology_index = "$data_dir/$ontology_index_dir";
    my $dest_ontology_index = "$temp_dir/$ontology_index_dir";

    dircopy($test_ontology_index, $dest_ontology_index)
      or die "'$!' while copying $test_ontology_index to $dest_ontology_index\n";
  }

  $::test_mode = 1;

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

  my $psgi_script_name = $self->root_dir() . '/script/canto_psgi.pl';
  my $app = Plack::Util::load_psgi($psgi_script_name);
  if ($ENV{CANTO_DEBUG}) {
    $app = Plack::Middleware::Debug->wrap($app);
  }

  my $cookie_jar = $self->cookie_jar();

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

 Usage   : my $test_util = Canto::TestUtil->new();
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

 Usage   : my $test_util = Canto::TestUtil->new();
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

 Usage   : my $test_util = Canto::TestUtil->new();
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

 Usage   : my $test_util = Canto::TestUtil->new();
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

=head2 chado_schema

 Usage   : my $test_util = Canto::TestUtil->new();
           $test_util->init_test();
           my $chado_schema = $test_util->chado_schema();
 Function: Return a schema object for the test chado database
 Args    : name

=cut
sub chado_schema
{
  my $self = shift;
  return $self->{chado_schema};
}

=head2 temp_dir

 Usage   : my $temp_dir_name = Canto::TestUtil::temp_dir()
 Function: Create a temporary directory for this test
 Args    : None

=cut
sub temp_dir
{
  (my $test_name = $0) =~ s!.*/(.*)(?:\.t)?!$1!;

  return tempdir("/tmp/canto_test_${test_name}_$$.XXXXX", CLEANUP => 1);
}

sub _check_dir
{
  my $dir = shift;
  return -d "$dir/etc" && -d "$dir/lib";
}

=head2 test_track_db_name

 Usage   : my $db_file_name =
             Canto::TestUtil::test_track_db_name($config, $test_name);
 Function: Return the TrackDB database file name for the given test
 Args    : $config - a Canto::Config object
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
             Canto::TestUtil::make_track_test_db($config, $test_name);
 Function: Make a copy of the empty template track database and return a schema
           object for it, or use the supplied file as the template database
 Args    : $config - a Canto::Config object
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

  return (Canto::DBUtil::schema_for_file($config, $track_test_db_file,
                                          'Track'),
          $track_test_db_file);
}


# pubmed IDs of publications for which we will load all data from pubmed:
my @test_pub_ids = (
  7958849, 19351719, 17304215, 19686603, 19160458, 19664060, 19041767,
  19037101, 19436749, 7518718, 18430926, 19056896, 18426916, 20976105,
  20622008, 19756689, 16641370, 20870879, 18556659, 19211838, 19627505,
  21801748, 10467002,
);

=head2 create_pubmed_test_xml

 Usage   : Canto::TestUtil::create_pubmed_test_xml();
 Function: Create a test file for PubMed code tests by downloading XML from
           PubMed
 Args    : none
 Returns : none

=cut
sub create_pubmed_test_xml
{
  my $self = shift;

  my $config = Canto::Config->get_config();

  my $xml = Canto::Track::PubmedUtil::get_pubmed_xml_by_ids($config,
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
  my $default_db_name = shift;

  my $load_util = Canto::Track::LoadUtil->new(schema => $schema,
                                              default_db_name => $default_db_name);

  map {
    my $uniquename = $Canto::Track::PubmedUtil::PUBMED_PREFIX . ":$_";
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
  Canto::Track::PubmedUtil::load_pubmed_xml($schema, $xml, 'admin_load');

  my $curatable_term = $schema->resultset('Cvterm')->find({ name => 'Curatable' });
  my @pubs = $schema->resultset('Pub')->search({ -or => [ uniquename => 'PMID:19756689',
                                                          uniquename => 'PMID:18426916' ] });

  map {
    $_->triage_status($curatable_term);
    $_->update();
  } @pubs;

  my $feature_or_region_term =
    $schema->resultset('Cvterm')->find({ name => 'Sequence feature or region' });

  my $pub_19351719 = $schema->resultset('Pub')->find({ uniquename => 'PMID:19351719' });

  $pub_19351719->triage_status($feature_or_region_term);
  $pub_19351719->update();
}

=head2 make_base_track_db

 Usage   : my $schema =
             Canto::TestUtil::make_base_track_db($config, $db_file_name);
 Function: Create a TrackDB for testing with basic data: curation data, sample
           genes and publication information
 Args    : $config - a Canto::Config object (including the test properties)
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
  my $pco_obo_file = $config->{test_config}->{test_peco_obo_file};
  my $relationship_obo_file = $config->{relationship_ontology_path};

  my $track_db_template_file = $config->{track_db_template_file};

  unlink $db_file_name;
  copy $track_db_template_file, $db_file_name or die "$!\n";

  my $schema = Canto::DBUtil::schema_for_file($config, $db_file_name, 'Track');
  my $load_util = Canto::Track::LoadUtil->new(schema => $schema,
                                              default_db_name => $config->{default_db_name});

  if ($load_data) {
    my ($organism, $organism_2) = add_test_organisms($config, $schema);

    my $curation_load = Canto::Track::CurationLoad->new(schema => $schema,
                                                        default_db_name => $config->{default_db_name} );
    my $gene_load = Canto::Track::GeneLoad->new(schema => $schema,
                                                 organism => $organism);
    my $allele_load = Canto::Track::AlleleLoad->new(schema => $schema,
                                                 organism => $organism);
    my $gene_load_organism_2 =
      Canto::Track::GeneLoad->new(schema => $schema,
                                   organism => $organism_2);

    my $index_path = $config->data_dir_path('ontology_index_dir');

    my $ontology_index = Canto::Track::OntologyIndex->new(index_path => $index_path);
    $ontology_index->initialise_index();

    my @relationships_to_load = @{$config->{load}->{ontology}->{relationships_to_load}};

    my $ontology_load =
      Canto::Track::OntologyLoad->new(default_db_name => $config->{default_db_name},
                                      relationships_to_load => \@relationships_to_load,
                                      schema => $schema);

    my $synonym_types = $config->{load}->{ontology}->{synonym_types};

    $curation_load->load($curation_file);
    _load_extra_pubs($schema, $config->{default_db_name});
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
    $ontology_load->load($pco_obo_file, $ontology_index,
                         $synonym_types);

    $ontology_load->finalise();
    $ontology_index->finish_index();
  }

  $schema->storage()->disconnect();
}

=head2 add_test_organisms

 Usage   : my @orgs = Canto::TestUtil::add_test_organisms($config, $schema);
 Function: Create the test organisms
 Args    : $config - a Canto::Config object
           $schema - the TrackDB schema object
 Returns : a list of the new Organism objects

=cut
sub add_test_organisms
{
  my $config = shift;
  my $schema = shift;

  my @ret = ();

  my $test_config = $config->{test_config};
  my $load_util = Canto::Track::LoadUtil->new(schema => $schema,
                                              default_db_name => $config->{default_db_name});

  for my $org_conf (@{$test_config->{organisms}}) {
    push @ret, $load_util->get_organism($org_conf->{genus},
                                        $org_conf->{species},
                                        $org_conf->{taxonid});

  }

  return @ret;
}

=head2 curs_key_of_test_case

 Usage   : my $curs_key = Canto::TestUtil::curs_key_of_test_case($test_case);
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

  my $gene_lookup = Canto::Track::GeneLookup->new(config => $config,
                                                   schema => $trackdb_schema);

  for my $gene_details (@{$curs_config->{genes}}) {
    my @allele_detail_list = ();
    my $gene_identifier;
    if (ref($gene_details)) {
      $gene_identifier = $gene_details->{primary_identifier};
      if (defined $gene_details->{alleles}) {
        @allele_detail_list = @{$gene_details->{alleles}};
      }
    } else {
      $gene_identifier = $gene_details;
    }
    my $result = $gene_lookup->lookup([$gene_identifier]);
    my @found = @{$result->{found}};
    if (@found != 1) {
      die "Expected 1 result for $gene_identifier not ", scalar(@found)
    }

    my %new_genes = Canto::Controller::Curs->_create_genes($cursdb_schema, $result);

    if (keys %new_genes != 1) {
      die "Expected only 1 gene to be created";
    }

    my $new_gene = (values %new_genes)[0];

    for my $allele_details (@allele_detail_list) {
      my $allele_primary_identifier = $allele_details->{primary_identifier};
      my $allele_description = $allele_details->{description};
      my $allele_name = $allele_details->{name};
      my $allele_type = $allele_details->{type};

      my %create_args = (
        primary_identifier => $allele_primary_identifier,
        type => $allele_type,
        description => $allele_description,
        name => $allele_name,
        gene => $new_gene->gene_id(),
      );

      my $allele = $cursdb_schema->create_with_type('Allele', \%create_args);
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

  my $curator_manager = Canto::Track::CuratorManager->new(config => $config);
  $curator_manager->set_curator($curs_config->{curs_key}, $curs_config->{submitter_email},
                                $curs_config->{submitter_name});
  $curator_manager->accept_session($curs_config->{curs_key});

  if (@{$curs_config->{genes}} > 0) {
    my $state = Canto::Curs::State->new(config => $config);
    $state->set_state($cursdb_schema, Canto::Curs::State::SESSION_ACCEPTED(),
                      { force => Canto::Curs::State::CURATION_IN_PROGRESS() });
    $state->set_state($cursdb_schema, Canto::Curs::State::CURATION_IN_PROGRESS(),
                      { force => Canto::Curs::State::CURATION_IN_PROGRESS() });
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
    return Canto::DB::id_of_object($object);
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
        my $type_name = Canto::DB::table_name_of_class($class_name);

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

 Usage   : Canto::TestUtil::make_curs_db($config, $curs_config,
                                          $trackdb_schema);
 Function: Make a curs database for the given $curs_config and update the
           TrackDB given by $trackdb_schema.  See the test_config.yaml file
           for example curs test case configurations.
 Args    : $config - a Canto::Config object that includes the test properties
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
    Canto::TestUtil::curs_key_of_test_case($curs_config);

  my $create_args = {
    curs_key => $test_case_curs_key,
    pub => _get_pub_object($trackdb_schema, $curs_config->{uniquename}),
  };

  my $curs_object = $trackdb_schema->create_with_type('Curs', $create_args);

  my $curs_file_name =
    Canto::Curs::make_long_db_file_name($config, $test_case_curs_key);
  unlink $curs_file_name;

  my ($cursdb_schema, $cursdb_file_name) =
    Canto::Track::create_curs_db($config, $curs_object);

  if (exists $curs_config->{submitter_email}) {
    _load_curs_db_data($config, $trackdb_schema, $cursdb_schema, $curs_config);
  }

  return ($cursdb_schema, $cursdb_file_name);
}

=head2 publications_xml_file

 Usage   : my $xml_filename = Canto::TestUtil::publications_xml_file
 Function: return the name of the test data file of XML from PubMed
 Args    : none

=cut
sub publications_xml_file
{
  my $self = shift;

  return $self->root_dir() . '/t/data/entrez_pubmed.xml';
}

=head2 cookie_jar

 Usage   : my $jar = $self->cookie_jar();
 Function: Create and return a HTTP::Cookies object

=cut
sub cookie_jar
{
  my $self = shift;

  return HTTP::Cookies->new(
    file => "/tmp/canto_web_test_$$.cookies",
    autosave => 1,
  );
}

=head2 app_login

 Usage   : $test_util->app_login($cookie_jar, $app_call_back);
 Function: Log in as an admin user
 Args    : $cookie_jar - a HTTP::Cookies object
           $app_call_back - the callback object from test_psgi
 Returns : nothing

=cut
sub app_login
{
  my $self = shift;
  my $cookie_jar = shift;
  my $cb = shift;
  my $req_base = shift;
  my $dest_redirect_url = shift // 'http://localhost:5000/';

  if (!defined $cookie_jar) {
    croak "no cookie jar passed to app_login()";
  }

  if (!defined $cb) {
    croak "no callback passed to app_login()";
  }

  my $track_schema = $self->track_schema();

  my $admin_role =
    $track_schema->resultset('Cvterm')->find({ name => 'admin' });

  my $admin_people =
    $track_schema->resultset('Person')->
    search({ role => $admin_role->cvterm_id() });

  my $first_admin = $admin_people->first();
  if (!defined $first_admin) {
    croak "can't find an admin user";
  }

  # reset so that the database isn't open for reading, otherwise login
  # will time out waiting for a write lock
  $admin_people->reset();

  my $first_admin_email_address = $first_admin->email_address();
  my $first_admin_password = $first_admin->email_address();

  my $uri = new URI("http://localhost:5000/login");
  $uri->query_form(email_address => $first_admin_email_address,
                   password => $first_admin_password,
                   return_path => $dest_redirect_url,
                   submit => 'login',
                 );
  my $req = GET $uri;
  if (defined $req_base) {
    $req->header('X-Request-Base', "$req_base");
  }
  $cookie_jar->add_cookie_header($req);

  my $res = $cb->($req);
  if ($res->code != 302) {
    croak "couldn't login: " . $res->content();
  }
  $cookie_jar->extract_cookies($res);

  my $redirect_url = $res->header('location');
  if ($redirect_url ne $dest_redirect_url) {
    croak "login didn't redirect to the front page";
  }

  my $redirect_req = GET $redirect_url;
  if (defined $req_base) {
    $redirect_req->header('X-Request-Base', "$req_base");
  }
  $cookie_jar->add_cookie_header($redirect_req);

  my $redirect_res = $cb->($redirect_req);
  my $login_text = "Login successful";
  if ($redirect_res->content() !~ m/$login_text/) {
    croak q(after login page doesn't contain "$login_text");
  }

  return $res;
}

=head2 enable_access_control

 Usage   : $test_util->enable_access_control();
 Function: Turn on login / password access control that is normally
           disabled for testing
 Args    : none

=cut
sub enable_access_control
{
  $Canto::access_control_enabled = 1;
}

=head2 get_a_person

 Usage   : my $admin_person = $test_util->get_a_person("admin")
 Function: Return an arbitrary person with the given role from the database
 Args    : $role - a role name like "admin" or "user"
 Return  : A Person object

=cut

sub get_a_person
{
  my $self = shift;
  my $track_schema = shift;
  my $role = shift;

  my $admin_person_rs =
    $track_schema->resultset('Person')->search({ 'role.name' => $role,
                                                 'cv.name' => 'Canto user types' },
                                               { join => { role => 'cv' } });
  return $admin_person_rs->first();
}



1;
