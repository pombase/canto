package Canto::Role::MetadataAccess;

=head1 NAME

Canto::Role::MetadataAccess - Role for set and getting from the metadata table

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Role::MetadataAccess

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

=head2 set_metadata

 Usage   : $self->set_metadata($schema, $key, $value);
 Function: Set a key/value pair in the metadata table.  If value in undefined,
           remove the current row with the given key.  If a key already exists
           it will be updated with the new value
 Args    : $schema - the CursDB schema object
           $key - the key
           $value - the new value or undef to remove it
 Returns : nothing

=cut
sub
  set_metadata
{
  my $self = shift;

  if (@_ < 3) {
    croak "not enough arguments to set_metadata()";
  }

  my $schema = shift;
  my $key = shift;
  my $value = shift;

  if (defined $value) {
    $schema->resultset('Metadata')->update_or_create({ key => $key,
                                                       value => $value });
  } else {
    my $metadata = $schema->resultset('Metadata')->find({ key => $key });
    if (defined $metadata) {
      $metadata->delete();
    }
  }
}

=head2 get_metadata

 Usage   : my $value = $self->get_metadata($schema, $key);
 Function: Return the value in the row with the given key in the metadata table
           or undef if there is no row with that key
 Args    : $schema - the CursDB schema object
           $key - the key
 Returns : the value

=cut
sub get_metadata
{
  my $self = shift;
  my $schema = shift;
  my $key = shift;

  if (!defined $key) {
    croak "not enough arguments to get_metadata()";
  }

  my $metadata_obj = $schema->resultset('Metadata')->find({ key => $key });
  if (defined $metadata_obj) {
    return $metadata_obj->value();
  } else {
    return undef;
  }
}

=head2 unset_metadata

 Usage   : unset_metadata($schema, $key);
 Function: delete the row with the given key in the metadata table
 Args    : $schema - the CursDB schema object
           $key - the key
 Returns : Nothing

=cut
sub unset_metadata
{
  my $self = shift;
  my $schema = shift;
  my $key = shift;

  if (!defined $key) {
    croak "not enough arguments to unset_metadata()";
  }

  $schema->resultset('Metadata')->search({ key => $key })->delete();
}

=head2 all_metadata

 Usage   : my %all_metadata = $self->all_metadata($schema);
 Function: Return a hash containing all the metadata from the given schema.
 Args    : $schema - the CursDB schema object
 Return  : a hash corresponding to the keys and values of the metadata table

=cut

sub all_metadata
{
  my $self = shift;
  my $schema = shift;

  return map { ($_->key(), $_->value()) } $schema->resultset('Metadata')->all();
}

1;
