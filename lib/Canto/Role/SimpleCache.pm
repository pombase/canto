package Canto::Role::SimpleCache;

=head1 NAME

Canto::Role::SimpleCache - Add a cache attribute to a class

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Role::SimpleCache

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

use Moose::Role;

use Canto::Cache;

requires 'config';

has cache => (is => 'ro', init_arg => undef, lazy_build => 1);

sub _build_cache
{
  my $self = shift;

  my $cache = Canto::Cache::get_cache($self->config(), __PACKAGE__);

  return $cache;
}

1;
