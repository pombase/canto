package PomCur::Track::TrackAdaptor;

=head1 NAME

PomCur::Track::TrackAdaptor -
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

    perldoc PomCur::Track::TrackAdaptor

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

use PomCur::TrackDB;

requires 'config';

has 'schema' => (
  is => 'ro',
  lazy_build => 1,
);

sub _build_schema {
  my $self = shift;

  my $config = $self->config();

  return PomCur::TrackDB->new(config => $config);
};

1;
