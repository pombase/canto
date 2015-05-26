package Canto::Util;

=head1 NAME

Canto::Util - Utility methods

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Util

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(trim);

my $iso_date_template = "%4d-%02d-%02d";

=head2 get_current_datetime

 Usage   : my $datetime_string = Canto::Util::get_current_datetime();
 Function: Return the current date and time as a string in the form:
           "2012-02-14 13:01:00"

=cut
sub get_current_datetime
{
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
  return sprintf "$iso_date_template %02d:%02d:%02d",
    1900+$year, $mon+1, $mday, $hour, $min, $sec;
}

=head2 trim

 Usage   : use Canto::Util qw(trim);
           my $trimmed_string = trim($some_string);
 Function: Return the string with start and ending whitespace removed

=cut

sub trim
{
  my $str = shift;

  return undef unless defined $str;

  $str =~ s/\s+$//;
  $str =~ s/^\s+//;

  return $str;
}

1;
