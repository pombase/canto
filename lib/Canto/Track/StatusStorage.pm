package Canto::Track::StatusStorage;

=head1 NAME

Canto::Track::StatusStorage - An interface to the TrackDB database used for
                               storing the status of a curation session

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::StatusStorage

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
use Moose;

with 'Canto::Role::Configurable';
with 'Canto::Track::TrackCursStorage';

sub _cv_rs
{
  my $schema = shift;

  return $schema->resultset('Cv')->
    find({ name => 'Canto cursprop types' });
}

sub _rs_and_type
{
  my $self = shift;
  my $curs = shift;
  my $type_name = shift;

  my $schema = $self->schema();

  my $terms_rs = _cv_rs($schema)->search_related('cvterms');
  my $type_cvterm = $terms_rs->find({ name => $type_name });

  if (!defined $type_cvterm) {
    die "Can't find Cvterm for $type_name\n";
  }

  my $cursprop_rs =
    $curs->search_related('cursprops',
                          { curs => $curs->curs_id(),
                            type => $type_cvterm->cvterm_id() });

  return ($cursprop_rs, $type_cvterm);
}

=head2 store

 Usage   : $status_storage->store($curs_key, $type, 'value');
       OR: $status_storage->store($curs_key, 'session_genes_count', $count);
       OR: $status_storage->store($curs_key, 'annotation_status', 'finished');
       OR: $status_storage->store($curs_key, 'approver_name')  # to delete
 Function: Store status information about a curation session in the Track
           database, without knowledge of the database schema.  The data
           will be stored in the cursprop table
 Args    : $curs_key  - the session key
           $type_name - the data type to store; there can only be one
                        value of each type; possible type names can be
                        queried with types();
           $value - the value, or undef to delete the stored status
 Returns : nothing

=cut

sub store
{
  my $self = shift;
  my $curs_key = shift;
  my $type_name = shift;
  my $value = shift;

  my $curs = $self->get_curs_object($curs_key);

  die 'no curs' unless $curs;

  my $guard = $self->schema()->txn_scope_guard();

  my ($cursprop_rs, $type_cvterm) = $self->_rs_and_type($curs, $type_name);

  $cursprop_rs->delete();

  if (defined $value) {
    $cursprop_rs->create({ curs => $curs->curs_id(),
                           type => $type_cvterm->cvterm_id(),
                           value => $value });
  }

  $guard->commit();
}

=head2

 Usage   : my $value = $status_storage->retrieve($type);
 Function: return a stored value
 Args    : $curs_key - the session key
           $type - the type name
 Returns : the stored value

=cut

sub retrieve
{
  my $self = shift;
  my $curs_key = shift;
  my $type_name = shift;

  my $schema = $self->schema();
  my $curs = $self->get_curs_object($curs_key);

  my ($cursprop_rs) = $self->_rs_and_type($curs, $type_name);

  my $first = $cursprop_rs->first();

  if (defined $first) {
    return $first->value();
  } else {
    return undef;
  }
}

=head2

 Usage   : my $value = $status_storage->types();
 Function: return a list of the possible type names
 Args    : none
 Returns : a list of names

=cut

sub types
{
  my $self = shift;

  my $schema = $self->schema();
  my $rs = _cv_rs($schema)->search_related('cvterms');

  return map { $_->name() } $rs->all();
}

1;
