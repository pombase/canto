package PomCur::Track::StatusStorage;

=head1 NAME

PomCur::Track::StatusStorage - An interface to the TrackDB database used for
                               storing the status of a curation session

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::StatusStorage

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

with 'PomCur::Role::Configurable';
with 'PomCur::Role::CursStorage';
with 'PomCur::Track::TrackCursStorage';

=head2 store

 Usage   : $status_storage->store('type', 'value');
       OR: $status_storage->store('genes_annotated', $count);
 Function: Store status information about a curation session in the Track
           database, without knowledge of the database schema.  The data
           will be stored in the curs_property table
 Args    : $type - the data type to store
           $value - the value
 Returns : nothing

=cut
sub store
{
  my $self = shift;
  my $type = shift;
  my $value = shift;

  my $schema = $self->schema();
  my $curs = $self->curs_object();

  die 'no curs' unless $curs;
  die 'no schema' unless $schema;

  warn "  STORE: $type $value\n";
}

1;
