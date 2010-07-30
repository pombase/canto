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

=head2 make_connect_string

 Usage    : my ($connect_string, $exists_flag) =
              PomCur::Curs::make_connect_string($config, $curs_key, $pubmedid);
 Function : Make a connect string to use for a curation session db and report
            if the database exists
 Args     : $config - the Config object
            $curs_key - the key (as a string) of the curation session

=cut
sub make_connect_string
{
  my $config = shift;
  my $curs_key = shift;

  my $data_directory = $config->{data_directory};

  my $file_name = "$data_directory/curs_${curs_key}.sqlite3";

  my $connect_string = "dbi:SQLite:dbname=$file_name";

  if (wantarray()) {
    return ($connect_string, -e $file_name);
  } else {
    return $connect_string;
  }
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

1;
