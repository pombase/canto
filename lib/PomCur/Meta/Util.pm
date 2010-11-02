package PomCur::Meta::Util;

use feature ':5.10';

=head1 NAME

PomCur::Meta::Util - Utilities for creating and managing tracking instances

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Meta::Util

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;

use File::Path;
use File::Copy qw(copy);

use PomCur::Config;
use PomCur::DBUtil;

=head2 needs_app_init

 Usage   : if (PomCur::Meta::Util::needs_app_init($app_name)) { ... }
 Function: Return true if the given application needs initialisation
 Args    : $app_name - the application name used for finding configuration files

=cut
sub app_initialised
{
  my $app_name = shift;

  my $deploy_config_file_name = $app_name . '_deploy.yaml';

  return -f $deploy_config_file_name;
}

=head2 initialise_app

 Usage   : PomCur::Meta::Util::initialise_app($app_name, $init_dir, $suffix)
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

  my $app_name = lc $config->{name};

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

  print $deploy_config_fh <<"EOF";
"Model::TrackModel":
  schema_class: 'PomCur::TrackDB'
  connect_info:
     - "dbi:SQLite:dbname=$dest_file"
data_directory: "$init_dir"
EOF

  close $deploy_config_fh or die "can't close $deploy_config_file_name: $!\n";

  return 1;
}

=head2

 Usage   : PomCur::Meta::Util::create_template_dbs();
 Function: Create empty template databases in the template directory and load
           them with the appropriate schemas.  Also populate the tables with
           basic data needed for loading genes and ontologies.  eg. load the
           synonym_type cv.

=cut
sub create_template_dbs
{
  my $config = PomCur::Config::get_config();

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

  my $track_file = $model_files{track};
  my $track_schema =
    PomCur::DBUtil::schema_for_file($config, $track_file, 'Track');

  initialise_tables($track_schema);
}


sub initialise_tables
{
  my $track_schema = shift;

#  add 'synonym_type' to cv ...
}

1;
