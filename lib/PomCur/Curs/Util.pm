package PomCur::Curs::Util;

=head1 NAME

PomCur::Curs::Util - Utility function for curation sessions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Curs::Util

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

sub module_display_name
{
  my $module_name = shift;

  (my $display_name = $module_name) =~ s/_/ /g;
  $display_name =~ s/go/GO/;
  $display_name =~ s/\b(\w)/\U$1/g;

  return $display_name;
}

1;
