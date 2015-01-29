package Canto::Meta::Util;

use feature ':5.10';

=head1 NAME

Canto::Meta::Util - Utilities for creating and managing tracking instances

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Meta::Util

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;

use File::Path;
use File::Copy qw(copy);

use Canto::Config;
use Canto::DBUtil;
use Canto::DB;
use Canto::Track::OntologyIndex;
use Canto::Track::OntologyLoad;

use YAML qw(Load Dump);

=head2 needs_app_init

 Usage   : if (Canto::Meta::Util::needs_app_init($app_name)) { ... }
 Function: Return true if the given application needs initialisation
 Args    : $app_name - the application name used for finding configuration files
           $suffix - the file name suffix to use, defaults to "deploy", ie.
                     <app_name>_deploy.yaml

=cut
sub app_initialised
{
  my $app_name = lc shift;
  my $suffix = shift // 'deploy';

  my $deploy_config_file_name = $app_name . "_$suffix.yaml";

  return -f $deploy_config_file_name;
}

=head2 initialise_app

 Usage   : Canto::Meta::Util::initialise_app($app_name, $init_dir, $suffix)
 Function: Initialise the properties and database directory for $app_name
 Args    : $app_name - the application name used for creating configuration
                       files
           $init_dir - the directory to create for holding database files and
                       the tracking sqlite3 database
           $suffix - used to change the config file name for testing, defaults
                     to "deploy"
           $config_dir - for testing, set the directory to write the config file

=cut
sub initialise_app
{
  my $config = shift;
  my $init_dir = shift;
  my $suffix = shift // 'deploy';
  my $config_dir = shift // '.';

  my $app_name = lc Canto::Config::get_application_name();

  my $deploy_config_file_name = $app_name . '_' . $suffix . '.yaml';

  if (-d $init_dir) {
    opendir DIR, $init_dir or die "can't read directory $init_dir: $!\n";
    while (my $entry = readdir DIR) {
      next if($entry =~ /^\.\.?$/);
      closedir DIR;
      die "$0: directory ($init_dir) not empty, won't initialise\n";
    }
    closedir DIR;
  } else {
    if (-e $init_dir) {
      die "$0: $init_dir exists, but isn't an empty directory, won't initialise\n";
    }

    mkpath ($init_dir, {error => \my $err});

    if (@$err) {
      for my $diag (@$err) {
        my ($file, $message) = %$diag;
        warn "error: $message\n";
      }
      exit (1);
    }
  }

  my $track_db_template_file = $config->{track_db_template_file};
  my $dest_file = "$init_dir/track.sqlite3";

  if (!copy ($track_db_template_file, $dest_file)) {
    croak "Failed to copy $track_db_template_file to $dest_file: $!\n";
  }

  open (my $deploy_config_fh, '>',
        "$config_dir/$deploy_config_file_name") or
    die "can't open $deploy_config_file_name for writing: $!\n";

  my $new_config = {
    get_track_model_conf($dest_file),
    data_directory => $init_dir
  };

  print $deploy_config_fh Dump($new_config);

  close $deploy_config_fh or die "can't close $deploy_config_file_name: $!\n";

  return 1;
}

=head2 get_track_model_conf

 Usage   : my %conf = Canto::Meta::Util::get_track_model_conf($db_file)
 Function: Return a TrackDB configuration hash for adding to the Config
           object
 Args    : $db_file - the SQLite3 TrackDB database file
 Returns : a hash with one key: "Model::TrackModel"

=cut
sub get_track_model_conf
{
  my $db_file = shift;

  return (
    "Model::TrackModel" => {
      schema_class => 'Canto::TrackDB',
      connect_info => [
        "dbi:SQLite:dbname=$db_file"
      ],
    }
  );
}

=head2

 Usage   : Canto::Meta::Util::create_template_dbs();
 Function: Create empty template databases in the template directory and load
           them with the appropriate schemas.  Also populate the tables with
           basic data needed for loading genes and ontologies.  eg. load the
           synonym_type cv.

=cut
sub create_template_dbs
{
  my $config = Canto::Config::get_config();

  my %model_files = (
    track => $config->{track_db_template_file},
    curs => $config->{curs_db_template_file}
  );

  for my $model_name (keys %model_files) {
    unlink $model_files{$model_name};

    my $sql = "etc/$model_name.sql";

    print "Creating: $model_files{$model_name} from $sql\n";
    system "sqlite3 $model_files{$model_name} < etc/$model_name.sql";
  }
}

=head2 initialise_core_data

 Usage   : Canto::Meta::Util::initialise_core_data($config, $schema, $db_dir, $key);
 Function: Load core data into the given schema.  eg. cvterms used by other
           loaders
 Args    : $config - the Canto::Config object
           $schema - the schema to write to
           $db_dir - the directory containing the new database, used for
                     ontology index creation
           $key - the key to use when accessing the config hash
 Returns : Nothing

=cut
sub initialise_core_data
{
  my $config = shift;
  my $schema = shift;
  my $db_dir = shift;
  my $config_key = shift;

  my $initial_data_ref = $config->{db_initial_data}->{$config_key};

  return unless defined $initial_data_ref;

  my %initial_data = %{$initial_data_ref};

  for my $table_name (keys %initial_data) {
    for my $row_contents (@{$initial_data{$table_name}}) {
      my $class_name = $schema->class_name_of_table($table_name);

      $schema->resultset($class_name)->create($row_contents);
    }
  }

  if ($config_key eq 'track') {
    my $schema_version_cvterm =
      $schema->resultset('Cvterm')->find({ name => 'schema_version' });

    my $schema_version = $config->{schema_version};
    $schema->resultset('Metadata')->
      create({ type => $schema_version_cvterm->cvterm_id(),
               value => $schema_version });

    my $index_path = "$db_dir/ontology_index_dir";

    my $index = Canto::Track::OntologyIndex->new(index_path => $index_path);
    $index->initialise_index();

    my @relationships_to_load = @{$config->{load}->{ontology}->{relationships_to_load}};

    my $ontology_load = Canto::Track::OntologyLoad->new(schema => $schema,
                                                        relationships_to_load => \@relationships_to_load,
                                                        default_db_name => $config->{default_db_name});
    my $synonym_types = $config->{load}->{ontology}->{synonym_types};

    $ontology_load->load($config->{relationship_ontology_path}, $index, $synonym_types);

    $ontology_load->finalise();
    $index->finish_index();
  }
}

1;
