package Canto::Track::CuratorManager;

=head1 NAME

Canto::Track::CuratorManager - Interface managing curators in the Track
                                database

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::CuratorManager

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;

use Canto::Hooks::SessionAccepted;
use Canto::Curs;
use Canto::Util;

with 'Canto::Role::Configurable';
with 'Canto::Track::Role::Schema';

sub _curs_curator_rs
{
  my $self = shift;
  my $curs_key = shift;

  my $schema = $self->schema();
  my $curs_rs = $schema->resultset('Curs')->search({ curs_key => $curs_key });

  return
    $schema->resultset('CursCurator')
      ->search({
        'me.curs' => {
          -in => $curs_rs->get_column('curs_id')->as_query(),
        },
      });
}

sub _get_current_curator_row
{
  my $self = shift;
  my $curs_key = shift;

  my $where = 'curs_curator_id = (select max(curs_curator_id) from curs_curator where curs = me.curs)';

  my $curs_curator_rs =
    $self->_curs_curator_rs($curs_key)
         ->search({},
                  {
                    where => \$where,
                  });

  return $curs_curator_rs->first();
}

sub _format_curs_curator_row
{
  my $row = shift;

  my $current_curator = $row->curator();
  if (wantarray) {
    return ($current_curator->email_address(),
            $current_curator->name(),
            $current_curator->known_as(),
            $row->accepted_date(),
            defined $current_curator->role() && $current_curator->role()->name() ne 'admin',
            $row->creation_date(),
            $row->curs_curator_id());
  } else {
    return $current_curator->email_address();
  }
}

=head2 current_curator

 Usage   : $curator_manager->current_curator($curs_key);
 Function: Get the current curator of a curation session.  ie the curator of the
           curs_curator row with the highest curs_curator_id - the most recent.
 Args    : $curs_key - the curs_key for the session
 Return  : ($email, $name, $known_as, $accepted_date, $community_curated)
              - in an array context
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

  my $curs_curator_row = $self->_get_current_curator_row($curs_key);

  if (defined $curs_curator_row) {
    return _format_curs_curator_row($curs_curator_row);
 } else {
    return undef;
  }
}

=head2 session_curators

 Usage   : $curator_manager->session_curators($curs_key);
 Function: Return a summary of current and past curators of the given session.
 Args    : $curs_key - the curs_key for the session
 Return  : An array of curator information, ordered from oldest to newest.
           Each element in the array has the form:
            [$email, $name, $known_as, $accepted_date, $community_curated]
         note: the $accepted_date will be undef if the session hasn't been
               accepted by that curator
               $community_curated is a flag: 0 or 1

=cut

sub session_curators
{
  my $self = shift;
  my $curs_key = shift;

  return map {
    [_format_curs_curator_row($_)];
  } $self->_curs_curator_rs($curs_key)->search({}, { order_by => 'curs_curator_id' })->all();
}

=head2 set_curator

 Usage   : $curator_manager->set_curator($curs_key, $email);
 Function: set the curator of a curation session
 Args    : $curs_key - the curs_key for the session
           $email - the email address of the curator
 Return  : nothing

=cut

sub set_curator
{
  my $self = shift;
  my $curs_key = shift;

  die 'no curs_key passed to set_curator()' unless defined $curs_key;

  my $curs_curator_email = shift;

  die 'no curator email address passed to set_curator()'
    unless defined $curs_curator_email;

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

  if (!defined $curs_key) {
    croak "no curs_key passed to accept_session()\n";
  }

  my $curs_curator_row = $self->_get_current_curator_row($curs_key);

  if (defined $curs_curator_row) {
    my $current_date = Canto::Util::get_current_datetime();
    $curs_curator_row->accepted_date($current_date);
    $curs_curator_row->update();

    my $curs_schema = Canto::Curs::get_schema_for_key($self->config(), $curs_key);
    my $state = Canto::Curs::State->new(config => $self->config());
    my $metadata_storer = Canto::Curs::MetadataStorer->new(config => $self->config());
    $metadata_storer->set_metadata($curs_schema,
                                   Canto::Curs::State::ACCEPTED_TIMESTAMP_KEY(),
                                   Canto::Util::get_current_datetime());

    my $accept_hook_key = 'accept_hooks';
    my $hooks = $self->config()->{curator_manager}->{$accept_hook_key};

    if (defined $hooks) {
      if (ref $hooks eq 'ARRAY') {
        for my $hook (@$hooks) {
          no strict 'refs';
          my $hook_name = "Canto::Hooks::SessionAccepted::$hook";
          &{$hook_name}($self->config,
                        $self->schema(),
                        $curs_curator_row->curs(),
                        $curs_curator_row->curator());
        }
      } else {
        die "the $accept_hook_key config is not an array";
      }
    }
  } else {
    croak "can't accept session $curs_key as there is no current curator\n";
  }
}

1;
