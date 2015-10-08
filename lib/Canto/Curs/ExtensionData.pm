package Canto::Curs::ExtensionData;

=head1 NAME

Canto::Curs::ExtensionData - Objects representing GO style annotation extensions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::ExtensionData

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;

has structure => (isa => 'ArrayRef[ArrayRef[HashRef]]',
                  is => 'rw');

sub as_string
{
  my $self = shift;

  return join '|', map {
    my @part = @$_;

    join ',', map {
      $_->{relation} . '(' . $_->{rangeValue} . ')';
    } @part;
  } @{$self->{structure}};
}

1;
