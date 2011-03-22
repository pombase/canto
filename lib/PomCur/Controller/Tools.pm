package PomCur::Controller::Tools;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

PomCur::Controller::Tools - Controller for PomCur user tools

=head1 METHODS

=cut
sub triage :Local :Args() {
  my ($self, $c, $pub_id, %args) = @_;

  if (!defined $c->user() && $c->user()->role()->name() eq 'admin') {
    $c->stash()->{error} = "Log in as administrator to allow triaging";
    $c->forward('/front');
    $c->detach();
    return;
  }

  my $st = $c->stash();

  my $schema = $c->schema('track');

  if (defined $pub_id && defined $args{status}) {
    my $pub = $schema->find_with_type('Pub', $pub_id);

    my $status_id = $args{status};

    $pub->triage_status_id($status_id);
    $pub->update();

    $c->res->redirect('/tools/triage');
    $c->detach();
  }

  my $cv = $schema->find_with_type('Cv',
                                   { name => 'PomCur publication triage status' });
  my $new_cvterm = $schema->find_with_type('Cvterm',
                                           { cv_id => $cv->cv_id(),
                                             name => 'new' });

  my $constraint = {
    triage_status_id => $new_cvterm->cvterm_id()
  };

  my $pub = $schema->resultset('Pub')->search($constraint)->first();

  if (defined $pub) {
    $st->{title} = 'Triaging ' . $pub->uniquename();
    $st->{pub} = $pub;

    my @statuses =
      $schema->resultset('Cvterm')->search({ cv_id => $cv->cv_id() });

    $st->{pub_statuses} = [@statuses];

    $st->{template} = 'tools/triage.mhtml';
  } else {
    $c->flash()->{message} =
      'Triaging finished - no more un-triaged publications';
    $c->res->redirect('/');
    $c->detach();
  }
}


=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
