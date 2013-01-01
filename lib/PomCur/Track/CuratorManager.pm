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

sub current_curator
{
  my $self = shift;
  my $curs_key = shift;

  if (!defined $curs_key) {
    croak "no curs_key passed to current_curator()\n";
  }

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

  if (defined $curs_curator_first) {
    my $first_curator = $curs_curator_first->curator();
    if (wantarray) {
      return ($first_curator->email_address(),
              $first_curator->name());
    } else {
      return $first_curator->email_address();
    }
  } else {
    return undef;
  }
}

sub set_curator
{
  my $self = shift;
  my $curs_key = shift;
  my $curs_curator_email = shift;

  $curs_curator_email =~ s/(.*)\@(.*)/$1\@\L$2/;

  my $curs_curator_name = shift;

  my $schema = $self->schema();

  my $curator_rs = $schema->resultset('Person');
  my $curs_curator_email_rs =
    $curator_rs->search({ 'lower(email_address)' => lc $curs_curator_email });

  my $curator;

  if ($curs_curator_email_rs->count() > 0) {
    my $current_curator = $self->current_curator($curs_key);

    if (defined $current_curator && $current_curator eq $curs_curator_email) {
      return;
    }
    $curator = $curs_curator_email_rs->first();
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

1;
