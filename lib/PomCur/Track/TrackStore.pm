package PomCur::Track::TrackStore;

=head1 NAME

PomCur::Track::TrackStore - A role for Stores that get data from the TrackDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::TrackStore

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
  init_arg => undef
);

sub _build_schema {
  my $self = shift;

  my $config = $self->config();

  return PomCur::TrackDB->new($config);
};

1;
