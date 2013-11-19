package Canto::Track::TrackAdaptor;

=head1 NAME

Canto::Track::TrackAdaptor -
   A role for Adaptor classes that get data from the TrackDB.  Note,
   an adaptor can be either a Lookup (read-only) or a Storage object
   (read-write)

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::TrackAdaptor

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

use Canto::TrackDB;

with 'Canto::Track::Role::Schema';

1;
