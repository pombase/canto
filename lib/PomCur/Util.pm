package PomCur::Util;

=head1 NAME

PomCur::Util - Utility methods

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Util

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use perl5i::2;
use Moose;

my $iso_date_template = "%4d-%02d-%02d";

=head2 get_current_datetime

 Usage   : my $datetime_string = PomCur::Util::get_current_datetime();
 Function: Return the current date and time as a string in the form:
           "2012-02-14 13:01:00"

=cut
sub get_current_datetime
{
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
  return sprintf "$iso_date_template %02d:%02d:%02d",
    1900+$year, $mon+1, $mday, $hour, $min, $sec;
}

1;
