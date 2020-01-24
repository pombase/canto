package Canto::Track::AdaptorUtil;

=head1 NAME

Canto::Track::AdaptorUtil - Code for finding and loading adaptor classes

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::AdaptorUtil

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;

=head2

 Usage   : my $adaptor = Canto::Track::get_adaptor($config, 'gene');
 Function: return an initialised Lookup or Storage object of the given type
 Args    : $config - the Canto::Config object
           $adaptor_name - the adaptor type used to look up in the config
 Return  : a Adaptor object or undef if there isn't an adaptor of the
           given type configured

=cut
sub get_adaptor
{
  my ($config, $adaptor_name, $args) = @_;

  if (!defined $adaptor_name) {
    croak "no adaptor_name passed to get_adaptor()\n";
  }

  my $conf_name = "${adaptor_name}_adaptor";

  my $impl_class = $config->{implementation_classes}->{$conf_name};

  if (!defined $impl_class) {
    return undef;
  }

  my %args = ();

  if (defined $args) {
    %args = %$args;
  }

  eval "use $impl_class";
  die "failed to import $impl_class: $@" if $@;
  return $impl_class->new(config => $config, %args);
}

1;
