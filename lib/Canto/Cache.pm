package Canto::Cache;

=head1 NAME

Canto::Cache - Access a data cache

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Cache

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use warnings;
use strict;

use feature "state";

use CHI;

=head2 get_cache

 Usage   : my $cache = Canto::Cache::get_cache($config, $namespace);
 Function: Return a CHI cache object for the $namespace
 Args    : $config - a Config object
           $namespace - the cache namespace to pass to CHI
 Returns : the cache

=cut
sub get_cache
{
  my $config = shift;
  my $namespace = shift;

  state $caches = {};

  if (!exists $caches->{$namespace}) {
    my $cache;

    if (exists $config->{cache}->{memcached}) {
      $cache = CHI->new(namespace => $namespace,
                        driver => 'Memcached',
                        servers => $config->{cache}->{memcached}->{servers},
                        debug => 0,
                        l1_cache => { driver => 'RawMemory', global => 1 }
                      );
    } else {
      $cache = CHI->new(namespace => $namespace,
                        driver => 'RawMemory', global => 1);
    }
    $caches->{$namespace} = $cache;
  }

  return $caches->{$namespace};
}

1;
