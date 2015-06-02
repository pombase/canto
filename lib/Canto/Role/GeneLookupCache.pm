package Canto::Role::GeneLookupCache;

=head1 NAME

Canto::Role::GeneLookupCache - A role the adds caching to a GeneLookup

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Role::GeneLookupCache

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
use Carp;

with 'Canto::Role::SimpleCache';

requires 'config';

around 'lookup' => sub {
  my $orig = shift;
  my $self = shift;

  my $organism_name = 'any';

  my @args;
  if (@_ == 1) {
    @args = @{$_[0]};
  } else {
    my $options = $_[0];
    if (exists $options->{search_organism}) {
      $organism_name = $options->{search_organism}->{genus} . '_' .
        $options->{search_organism}->{species};
    }
    @args = @{$_[1]};
  }

  if (!defined $args[0]) {
    confess "no argument passed to lookup()";
  }

  my $cache_key = $organism_name . ':' . join '#@%', @args;
  my $cache = $self->cache();

  my $cached_value = $cache->get($cache_key);

  if (defined $cached_value) {
    return $cached_value;
  }

  my $ret_val = $self->$orig(@_);

  $cache->set($cache_key, $ret_val, $self->config()->{cache}->{chado_gene_timeout});

  return $ret_val;
};

1;
