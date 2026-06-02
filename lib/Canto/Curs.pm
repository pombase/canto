package Canto::Curs;

=head1 NAME

Canto::Curs - Utility methods for accessing curation sessions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs

=over 4

=back

=head1 COdata_ LICENSE

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
use Moose;

use Canto::CursDB;

=head2 make_connect_string

 Usage   : my $connect_string =
             Canto::Curs::make_connect_string($config, $curs_key);
           my ($connect_string, $exists_flag, $db_file_name) =
             Canto::Curs::make_connect_string($config, $curs_key);
 Function: Make a connect string to use for a curation session db and report
           if the database exists
 Args    : $config - the Config object
           $curs_key - the key (as a string) of the curation session
 Returns : $connect_string - the DBI connection string
           $exists_flag - true if and only if the database already exists
           $db_file_name - the full path to the database file

=cut
sub make_connect_string
{
  my $config = shift;
  my $curs_key = shift;

  my $file_name = make_long_db_file_name($config, $curs_key);

  my $connect_string = "dbi:SQLite:dbname=$file_name";

  if (wantarray()) {
    return ($connect_string, -e $file_name, $file_name);
  } else {
    return $connect_string;
  }
}


=head2 make_long_db_file_name

 Usage   : my $curs_db_file_name =
             Canto::Curs::make_long_db_file_name($config, $curs_key);
 Function: For the given curs key, return the full path of the corresponding
           SQLite file
 Args    : $config - the Config object
           $curs_key - the key (as a string) of the curation session

=cut
sub make_long_db_file_name
{
  my $config = shift;
  my $curs_key = shift;

  my $data_directory = $config->data_dir();

  my $filename = "$data_directory/" . make_db_file_name($curs_key);

  $filename =~ s://+:/:g;

  return $filename;
}

=head2 make_db_file_name

 Usage   : my $curs_db_file_name = Canto::Curs::make_db_file_name($curs_key);
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

 Usage    : my $key = Canto::Curs::make_curs_key();
 Function : Make a new random string to use as a key

=cut
sub make_curs_key
{
  my $ret_key = '';
  use integer;
  for (my $i = 0; $i < 4; $i++) {
    my $key_int = int(rand 2**16);
    $ret_key .= sprintf("%.4x", $key_int);
  }
  return $ret_key;
}

=head2

 Usage   : my $schema = Canto::Curs::get_schema($c);
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

 Usage   : my $schema = Canto::Curs::get_schema_for_key($config, $curs_key);
 Function: Get a schema object for the given curs_key
 Args    : $config - the config object
           $curs_key - the key (as a string) of the curation session
           $options
             - "cache_connection" - passed to cached_connect
 Return  : the schema or undef if the corresponding database doesn't exist

=cut
sub get_schema_for_key
{
  my $config = shift;
  my $curs_key = shift;
  my $options = shift // {};

  $options->{cache_connection} //= 1;

  my ($connect_string, $exists_flag) =
    Canto::Curs::make_connect_string($config, $curs_key);

  if ($exists_flag) {
    my $schema =
      Canto::CursDB->cached_connect($connect_string, undef, undef,
                                    $options);

    my $dbh = $schema->storage()->dbh();
    $dbh->do("PRAGMA foreign_keys = ON");

    return $schema;
  } else {
    return undef;
  }
}

1;
