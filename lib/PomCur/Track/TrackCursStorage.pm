package PomCur::Track::TrackCursStorage;

=head1 NAME

PomCur::Track::TrackCursStorage - Base class for storing data about a curation
                                  session in a track database

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::TrackCursStorage

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose::Role;

with 'PomCur::Track::TrackAdaptor';

requires 'curs_key';

has curs_object => (
  is => 'ro',
  isa => 'PomCur::TrackDB::Curs',
  builder => '_make_curs_object',
);

sub _make_curs_object
{
  my $self = shift;

  my $schema = $self->schema();
  my $curs_key = $self->curs_key();

  return $schema->find_with_type('Curs', { curs_key => $curs_key });
}

1;
