package PomCur::Track;

=head1 NAME

PomCur::Track - Utilities for the tracking database

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track

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
use Moose;

use File::Copy qw(copy);

use PomCur::Config;
use PomCur::Curs;

=head2

 Usage   : PomCur::Track::create_template_dbs();
 Function: create empty databases in the template directory and load them with
           the appropriate schemas

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

}

=head2 create_curs

 Usage   : PomCur::Track::create_curs_db($config, $curs_object);
 Function: Create a database for a curs, using the curs_key field of the object
           to create the database (file)name.
 Args    : $config - the Config object
           $curs - the Curs object
 Return  : none, die()s on failure

=cut
sub create_curs_db
{
  my $config = shift;
  my $curs = shift;

  my $pubmedid = $curs->pub()->pubmedid();
  my $curs_key = $curs->curs_key();

  my $exists_flag = 1;

  my $db_file_name = PomCur::Curs::make_db_file_name($config, $curs_key);

  if (-e $db_file_name) {
    die "Internal error: database already exists\n";
  }

  my $curs_db_template_file = $config->{curs_db_template_file};

  copy($curs_db_template_file, $db_file_name) or die "$!\n";
}

=head2 create_curs_db_hook

 Usage   : PomCur::Track::create_curs_db_hook($config, $curs_object);
 Function: Wrapper for create_curs_db() to be called from Edit::object()
 Args    : $c - the Catalyst object
           $curs - the Curs object

=cut
sub create_curs_db_hook
{
  my $c = shift;
  my $curs = shift;

  create_curs_db($c->config(), $curs);
}

=head2

 Usage   : my $store = PomCur::Track::get_store($config, 'gene');
 Function: return an initialised Store object of the given type
 Args    : $config - the PomCur::Config object
           $store_name - the store name used to look up in the config
 Return  : a Store object

=cut
sub get_store
{
  my ($config, $store_name) = @_;

  if (!defined $store_name) {
    croak "no store_name passed to get_store()\n";
  }

  my $impl_class = $config->{implementation_classes}->{"${store_name}_store"};

  eval "use $impl_class";
  return $impl_class->new(config => $config);
}

1;
