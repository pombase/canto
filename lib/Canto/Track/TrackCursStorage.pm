package Canto::Track::TrackCursStorage;

=head1 NAME

Canto::Track::TrackCursStorage - Base class for storing data about a curation
                                  session in a track database

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::TrackCursStorage

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Carp;
use Moose::Role;

with 'Canto::Track::TrackAdaptor';

=head2

 Usage   : my $curs = $self->get_curs_object($curs_key);
 Function: Find the Curs DBIx::Class object for the given key
 Args    : $curs_key - the session key
 Returns : the Curs object

=cut
sub get_curs_object
{
  my $self = shift;
  my $curs_key = shift;

  my $schema = $self->schema();

  return $schema->find_with_type('Curs', { curs_key => $curs_key });
}

1;
