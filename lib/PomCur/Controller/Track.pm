package PomCur::Controller::Track;

use parent 'Catalyst::Controller';

=head1 NAME

PomCur::Controller::Track - Actions for managing PomCur

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Controller::Track

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

use Moose;

sub index_page :Path :Args(0) {
  my ($self, $c) = @_;

  $c->stash->{title} = 'Admin page';
  $c->stash->{template} = 'track/index.mhtml';

  $c->stash->{model} = 'track';
}

sub assign_pub :Local {
  my ($self, $c) = @_;

  my $config = $c->config();

  my $return_path = $c->req()->param('pub-view-path');

  if (defined $c->req->param('curs-pub-assign-submit')) {
    my $pub_id = $c->req()->param('pub-id');
    my $person_id = $c->req()->param('pub-assign-person');

    my $schema = $c->schema('track');

    my $curs_schema;

    my $proc = sub {
      my $pub = $schema->resultset('Pub')->find({ pub_id => $pub_id });
      $pub->assigned_curator($person_id);
      if ($pub->curs() == 0) {
        my $person =
        $schema->resultset('Person')->find({ person_id => $person_id });
        my $admin_session = 0;
        if ($person->role()->name() eq 'admin') {
          $admin_session = 1;
        }
        my %create_args = (
          assigned_curator => $person_id,
          pub => $pub_id,
          curs_key => PomCur::Curs::make_curs_key(),
        );
        my $curs = $schema->create_with_type('Curs', { %create_args });
        ($curs_schema) = PomCur::Track::create_curs_db($c->config(), $curs, $admin_session);
      }
      $pub->update();
    };

    $schema->txn_do($proc);

    if (defined $curs_schema) {
      # call after txn_do() because otherwise it will time out because
      # the database is locked
      PomCur::Curs::State->new()->store_statuses($curs_schema);
    }
  } else {
    # cancelled
  }

  $c->res->redirect($return_path);
  $c->detach();
}

1;
