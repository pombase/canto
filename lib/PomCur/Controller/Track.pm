package PomCur::Controller::Track;

use parent 'Catalyst::Controller';

=head1 NAME

PomCur::Controller::Track - Actions for managing PomCur

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Controller::Track

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

sub index_page :Path :Args(0) {
  my ($self, $c) = @_;

  $c->stash->{title} = 'Start page';
  $c->stash->{template} = 'track/index.mhtml';

  $c->stash->{model} = 'track';
}

1;
