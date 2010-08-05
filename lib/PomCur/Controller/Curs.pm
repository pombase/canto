package PomCur::Controller::Curs;

use parent 'Catalyst::Controller';

=head1 NAME

PomCur::Controller::Curs - curs (curation session) controller

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Controller::Curs

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

sub start : LocalRegex('^([0-9a-f]{8})') {
  my ($self, $c) = @_;

  $c->stash->{title} = 'TEST';
  $c->stash->{template} = 'curs/index.mhtml';

  $c->stash->{token} = $c->req->captures->[0];
}

1;
