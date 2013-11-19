package Canto::Role::GeneNames;

=head1 NAME

Canto::Role::GeneNames - A role with methods for display gene names

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Role::GeneNames

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Carp;
use Moose::Role;

requires 'primary_name';
requires 'primary_identifier';

=head2

 Usage   : my $display_name = $gene->display_name()
 Function: return the primary_name if set, primary_identifier otherwise

=cut
sub display_name
{
  my $self = shift;

  my $name = $self->primary_name();

  if (defined $name) {
    return $name;
  } else {
    return $self->primary_identifier();
  }
}

=head2

 Usage   : my $display_name = $gene->long_display_name()
 Function: Return a string containing the name and identifier, if
           the name is set. eg. "cdc11 (SPCC1739.11c)" otherwise just
           return the primary_identifier eg. "SPCC1739.10"

=cut
sub long_display_name
{
  my $self = shift;

  my $name = $self->primary_name();
  my $identifier = $self->primary_identifier();

  if (defined $name) {
    return "$name ($identifier)";
  } else {
    return $identifier;
  }
}

1;
