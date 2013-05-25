package PomCur::Track::CuratorManager;

=head1 NAME

PomCur::Track::CuratorManager - Interface managing curators in the Track
                                database

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::CuratorManager

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;

with 'PomCur::Role::Configurable';
with 'PomCur::Track::TrackAdaptor';

sub _get_current_current_row
{
  my $self = shift;
  my $curs_key = shift;

  my $schema = $self->schema();
  my $curs_rs = $schema->resultset('Curs')->search({ curs_key => $curs_key });

  my $where = 'curs_curator_id = (select max(curs_curator_id) from curs_curator where curs = me.curs)';

  my $curs_curator_rs =
    $schema->resultset('CursCurator')
           ->search({
             'me.curs' => {
               -in => $curs_rs->get_column('curs_id')->as_query(),
             },
           },
           {
             where => \$where,
           });

  my $curs_curator_first = $curs_curator_rs->first();

}

=head2 current_curator

 Usage   : $curator_manager->current_curator($curs_key);
 Function: Get the current curator of a curation session.  ie the curator of the
           curs_curator row with the highest curs_curator_id - the most recent.
 Args    : $curs - a TrackDB Curs or a curs_key that will be looked up
 Return  : ($email, $name, $accepted_date) - in an array context
           $email - in a scalar context
         note: the $accepted_date will be undef if the session hasn't been
               accepted yet

=cut
sub current_curator
{
  my $self = shift;
  my $curs_key = shift;

  if (!defined $curs_key) {
    croak "no curs_key passed to current_curator()\n";
  }

  my $curs_curator_row = $self->_get_current_current_row($curs_key);

  if (defined $curs_curator_row) {
    my $current_curator = $curs_curator_row->curator();
    if (wantarray) {
      return ($current_curator->email_address(),
              $current_curator->name(),
              $curs_curator_row->accepted_date());
    } else {
      return $current_curator->email_address();
    }
  } else {
    return undef;
  }
}

=head2 set_curator

 Usage   : $curator_manager->set_curator($curs_key, $email, $name);
 Function: set the curator of a curation session
 Args    : $curs - a TrackDB Curs or a curs_key that will be looked up
           $email - the email address of the curator
           $name the name of the curator
 Return  : nothing

=cut

sub set_curator
{
  my $self = shift;
  my $curs_key = shift;

  die unless defined $curs_key;

  my $curs_curator_email = shift;

  $curs_curator_email =~ s/(.*)\@(.*)/$1\@\L$2/;

  my $curs_curator_name = shift;

  my $schema = $self->schema();

  my $curator_rs = $schema->resultset('Person');
  my $curs_curator_email_rs =
    $curator_rs->search({ 'lower(email_address)' => lc $curs_curator_email });

  my $curator;

  if ($curs_curator_email_rs->count() > 0) {
    $curator = $curs_curator_email_rs->first();

    if (defined $curs_curator_name && length $curs_curator_name > 0 &&
      (!defined $curator->name() || $curator->name() ne $curs_curator_name)) {

      $curator->name($curs_curator_name);
      $curator->update();
    }
  } else {
    my $user_role_id =
      $schema->find_with_type('Cvterm', { name => 'user' })->cvterm_id();
    $curator = $curator_rs->create({ name => $curs_curator_name,
                                     email_address => $curs_curator_email,
                                     role => $user_role_id,
                                   });
  }

  my $curs_rs = $schema->resultset('Curs')->search({ curs_key => $curs_key });

  my $curs = $curs_rs->first();

  if (!defined $curs) {
    croak "couldn't find a curs with the curs_key: $curs_key";
  }

  $schema->resultset('CursCurator')->create(
    {
      curs => $curs->curs_id(),
      curator => $curator->person_id(),
    }
  );
}

=head2 accept_session

 Usage   : $curator_manager->accept_session($curs_key);
 Function: Set the "accepted" state on the curs_curator by setting the
           accepted_date field to the current date (rather than the default,
           null).
 Args    : $curs_key - a curs_key that will be looked up to find the Curs and
                       CursCurator to act on
 Return  : Nothing, but dies if there is no current curator for the Curs given
           by $curs_key.

=cut

sub accept_session
{
  my $self = shift;
  my $curs_key = shift;

  my $curs_curator_row = $self->_get_current_current_row($curs_key);

  if (defined $curs_curator_row) {
    my $current_date = PomCur::Util::get_current_datetime();
    $curs_curator_row->accepted_date($current_date);
    $curs_curator_row->update();
  } else {
    croak "can't accept session $curs_key as there is no current curator\n";
  }
}

1;
