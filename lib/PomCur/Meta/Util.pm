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

=head2 needs_app_init

 Usage   : if (PomCur::Meta::Util::needs_app_init($app_name)) { ... }
 Function: Return true if the given application needs initialisation
 Args    : $app_name - the application name used for finding configuration files

=cut
sub app_initialised
{
  my $app_name = shift;

  my $deploy_config_file_name = $app_name . '_deploy.yml';

  return -f $deploy_config_file_name;
}

=head2 initialise_app

 Usage   : PomCur::Meta::Util::initialise_app($app_name, $init_dir, $suffix)
 Function: Initialise the properties and database directory for $app_name
 Args    : $app_name - the application name used for creating configuration
                       files
           $init_dir - the directory to create for holding database files and
                       the tracking sqlite3 database
           $suffix - use to change the config file name for testing

=cut
sub initialise_app
{
  my $app_name = shift;
  my $init_dir = shift;
  my $suffix = shift // 'deploy';

  my $deploy_config_file_name = $app_name . '_' . $suffix . '.yml';

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

  use PomCur::Config;

  my $config_file_name = $app_name . '.yaml';
  my $config = PomCur::Config->new($config_file_name);
  my $track_db_template_file = $config->{track_db_template_file};
  my $dest_file = "$init_dir/track.sqlite3";

  copy ($track_db_template_file, $dest_file);

  open my $deploy_config_fh, '>', $deploy_config_file_name or
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

1;
