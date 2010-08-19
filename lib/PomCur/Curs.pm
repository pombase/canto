package PomCur::Curs;

=head1 NAME

PomCur::Curs - Utility methods for accessing curation sessions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Curs

=over 4

=back

=head1 COdata_ LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;

use PomCur::CursDB;

=head2 make_connect_string

 Usage   : my ($connect_string, $exists_flag) =
             PomCur::Curs::make_connect_string($config, $curs_key, $pubmedid);
 Function: Make a connect string to use for a curation session db and report
           if the database exists
 Args    : $config - the Config object
           $curs_key - the key (as a string) of the curation session

=cut
sub make_connect_string
{
  my $config = shift;
  my $curs_key = shift;

  my $file_name = make_long_db_file_name($config, $curs_key);

  my $connect_string = "dbi:SQLite:dbname=$file_name";

  if (wantarray()) {
    return ($connect_string, -e $file_name);
  } else {
    return $connect_string;
  }
}


=head2 make_long_db_file_name

 Usage   : my $curs_db_file_name =
             PomCur::Curs::make_long_db_file_name($config, $curs_key);
 Function: For the given curs key, return the full path of the corresponding
           SQLite file
 Args    : $config - the Config object
           $curs_key - the key (as a string) of the curation session

=cut
sub make_long_db_file_name
{
  my $config = shift;
  my $curs_key = shift;

  my $data_directory = $config->{data_directory};

  return "$data_directory/" . make_db_file_name($curs_key);
}

=head2 make_db_file_name

 Usage   : my $curs_db_file_name = PomCur::Curs::make_db_file_name($curs_key);
 Function: For the given curs key, return the file name of the corresponding
           SQLite file, without the directory path
 Args    : $curs_key - the key (as a string) of the curation session

=cut
sub make_db_file_name
{
  my $curs_key = shift;

  return "curs_${curs_key}.sqlite3";
}

=head2 create_curs_key

 Usage    : my $key = PomCur::Curs::make_curs_key();
 Function : Make a new random string to use as a key

=cut
sub make_curs_key
{
  my $key_int = int(rand 2**32);
  return sprintf("%.8x", $key_int);
}

=head2

 Usage   : my $schema = PomCur::Curs::get_schema($c);
 Function: Get a schema object for the current curs, based on the curs_key in
           the path
 Args    : $c - The Catalyst object
 Return  : the schema

=cut
sub get_schema
{
  my $c = shift;
  my $curs_key = $c->stash()->{curs_key};

  if (defined $curs_key) {
    my $config = $c->config();
    return get_schema_for_key($config, $curs_key);
  } else {
    croak "internal error: no curs_key in the stash\n";
  }
}

=head2

 Usage   : my $schema = PomCur::Curs::get_schema_for_key($config, $curs_key);
 Function: Get a schema object for the given curs_key
 Args    : $config - the config object
           $curs_key - the key (as a string) of the curation session
 Return  : the schema

=cut
sub get_schema_for_key
{
  my $config = shift;
  my $curs_key = shift;

  return PomCur::CursDB->connect(make_connect_string($config, $curs_key));
}

1;
