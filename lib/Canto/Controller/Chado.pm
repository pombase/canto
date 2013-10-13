package Canto::Controller::Chado;

use parent 'Catalyst::Controller';

=head1 NAME

Canto::Controller::Chado - Home for Chado actions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Controller::Chado

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

sub chado :Path :Args(0) {
  my ($self, $c) = @_;

  $c->stash->{title} = 'Chado home';
  $c->stash->{template} = 'chado/index.mhtml';

  $c->stash->{model} = 'chado';
}

1;
