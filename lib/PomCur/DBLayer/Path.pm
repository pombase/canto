package PomCur::DBLayer::Path;

=head1 NAME

PomCur::DBLayer::Path - A path through the model

=head1 DESCRIPTION

This class describes a path through the objects in the database.  When we
are looking at a Biosample object, examples paths are
 "name" - the "name" attribute of the biosample
 "ecotype" - the ecotype reference
 "ecotype->description" - the ecotype description
 "ecotype->organism" - the organism referred to by the ecotype reference in
                       this biosample
 "ecotype->organism->species" - the species of the organism of the ecotype

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::DBLayer::Path

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Scalar::Util qw(blessed);

use Moose;

#has 'schema' => (is => 'ro', isa => 'PomCur::DB', required => 1);

=head2 path_string

 The attribute defining the path, in the form '[bit]->[other_bit]->...'

=cut
has 'path_string' => (is => 'ro', required => 1);

=head2 bits

 Usage   : my @bits = $path->bits();
 Function: Return a list containing the parts of the Path, eg. if the
           path_string is "ecotype->organism", return qw(ecotype organism)
 Args    : None

=cut
sub bits
{
  my $self = shift;

  return split /->/, $self->{path_string};
}

=head2

 Usage   : my $object_or_value = $path->resolve($object);
 Function: Follow a path from the given object, returning the object or value
           at the end.  eg. For a biosample object, for path "ecotype->organism"
           we might get the arabidopsis row from the organism table.  The path
           "ecotype->organism->species" might give us "thaliana"
 Args    : $object - an object

=cut
sub resolve
{
  my $self = shift;

  my $current_value = shift;

  if (!defined $current_value) {
    croak 'undefined object passed to resolve()';
  }

  for my $bit ($self->bits()) {
    if (blessed $current_value &&
        $current_value->can($bit)) {
      $current_value = $current_value->$bit();
    } else {
      $current_value = $current_value->{$bit};
    }
  }

  return $current_value;
}

1;
