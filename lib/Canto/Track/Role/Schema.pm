package Canto::Track::Role::Schema;

=head1 NAME

Canto::Track::Role::Schema - A Role to add a (TrackDB) schema attribute

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::Role::Schema

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

use Moose::Role;

requires 'config';

has 'schema' => (
  is => 'ro',
  lazy_build => 1,
);

sub _build_schema {
  my $self = shift;

  my $config = $self->config();

  return Canto::TrackDB->new(config => $config);
};

1;
