package PomCur::CurModules::GOModule;

=head1 NAME

PomCur::CurModules::GOModule - Implementation class for GO annotation

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::CurModules::GOModule

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

extends 'PomCur::CurModule';

has 'ontologies' => (
  is => 'ro',
  isa => 'ArrayRef[Str]',
);

1;
