package Canto::Role::CheckACL;

=head1 NAME

Canto::Role::CheckACL - Return the access privileges of a user

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Role::CheckACL

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

use warnings;
use Moose::Role;

sub check_access
{
  my $self = shift;
  my $c = shift;

  if ($c->user_exists() && $c->user()->role()->name() eq 'admin') {
    return {
      # not very subtle for now:
      view => 1,
      edit => 1,
      delete => 1,
      export => 1,
      dump => 1,
      user_management => 1,
    }
  } else {
    return {};
  }
}

1;
