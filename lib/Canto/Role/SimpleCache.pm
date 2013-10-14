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

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

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
