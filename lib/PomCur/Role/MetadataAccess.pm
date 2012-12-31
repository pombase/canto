package PomCur::Role::MetadataAccess;

=head1 NAME

PomCur::Role::MetadataAccess - Role for set and getting from the metadata table

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Role::MetadataAccess

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose::Role;

=head2 set_metadata

 Usage   : set_metadata($schema, $key, $value);
 Function: Set a key/value pair in the metadata table.  If value in undefined,
           remove the current row with the given key.  If a key already exists
           it will be updated with the new value
 Args    : $schema - the CursDB schema object
           $key - the key
           $value - the new value or undef to remove it
 Returns : nothing

=cut
sub set_metadata
{
  my $self = shift;

  if (@_ < 3) {
    croak "not enough arguments to get_metadata()";
  }

  my $schema = shift;
  my $key = shift;
  my $value = shift;

  die if $key eq 'submitter_email';  # temporary hack to catch old code

  if (defined $value) {
    $schema->resultset('Metadata')->update_or_create({ key => $key,
                                                       value => $value });
  } else {
    my $guard = $schema->txn_scope_guard();

    my $metadata = $schema->resultset('Metadata')->find({ key => $key });
    if (defined $metadata) {
      $metadata->delete();
    }

    $guard->commit();
  }
}

=head2 get_metadata

 Usage   : my $value = get_metadata($schema, $key);
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

  die if $key eq 'submitter_email';  # temporary hack to catch old code

  my $metadata_obj = $schema->resultset('Metadata')->find({ key => $key });
  if (defined $metadata_obj) {
    return $metadata_obj->value();
  } else {
    return undef;
  }
}

=head2 get_metadata

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

1;
