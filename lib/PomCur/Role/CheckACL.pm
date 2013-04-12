package PomCur::Role::CheckACL;

=head1 NAME

PomCur::Role::CheckACL - Return the access privileges of a user

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Role::CheckACL

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

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
      view => 1,
      edit => 1,
      delete => 1,
    }
  } else {
    return {};
  }
}

1;
