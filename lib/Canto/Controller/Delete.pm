package Canto::Controller::Delete;

=head1 NAME

Canto::Controller::Delete - actions for deleting

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Controller::Delete

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

use strict;
use warnings;
use Carp;

use base 'Catalyst::Controller';

=head2 object

 Function: delete given object
 Args    : $type - object type/table
           $object_id - the object id

=cut
sub object : Local {
  my ($self, $c, $type, $object_id) = @_;

  my $object = undef;

  my $st = $c->stash;

  if (!defined $c->user()) {
    $st->{error} = "Log in to allow deletion";
  } else {
    my $class_name = Canto::DB::class_name_of_table($type);
    $object = $c->schema()->find_with_type($class_name, "${type}_id" => $object_id);

    $c->schema()->txn_do(sub {
                           $object->delete();
                         });

    push @{$st->{message}}, "Deleted: $type $object_id";
  }

  $c->forward('/front');
  $c->detach();
}
1;
