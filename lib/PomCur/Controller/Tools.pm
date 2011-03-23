package PomCur::Controller::Tools;

use strict;
use warnings;
use parent 'Catalyst::Controller';

sub _get_status_cv
{
  my $schema = shift;

  my $cv_name = 'PomCur publication triage status';
  return $schema->find_with_type('Cv', { name => $cv_name });
}

sub _get_next_triage_pub
{
  my $schema = shift;

  my $cv = _get_status_cv($schema);
  my $new_cvterm = $schema->find_with_type('Cvterm',
                                           { cv_id => $cv->cv_id(),
                                             name => 'New' });

  my $constraint = {
    triage_status_id => $new_cvterm->cvterm_id()
  };

  my $options = {
    # nasty hack to order by pubmed ID
    order_by => {
      -asc => "cast((case me.uniquename like 'PMID:%' WHEN 1 THEN " .
        "substr(me.uniquename, 6) ELSE me.uniquename END) as integer)"
    }
  };

  return $schema->resultset('Pub')->search($constraint, $options)->first();
}

=head1 NAME

PomCur::Controller::Tools - Controller for PomCur user tools

=head1 METHODS

=cut
sub triage :Local {
  my ($self, $c) = @_;

  if (!defined $c->user() || $c->user()->role()->name() ne 'admin') {
    $c->stash()->{error} = "Log in as administrator to allow triaging";
    $c->forward('/front');
    $c->detach();
    return;
  }

  my $st = $c->stash();
  my $schema = $c->schema('track');
  my $cv = _get_status_cv($schema);

  my $next_pub = undef;

  if ($c->req()->param('submit')) {
    my $guard = $schema->txn_scope_guard;

    my $pub_id = $c->req()->param('triage-pub-id');
    my $status_name = $c->req()->param('submit');

    my $pub = $schema->find_with_type('Pub', $pub_id);

    my $status = $schema->find_with_type('Cvterm', { name => $status_name,
                                                     cv_id => $cv->cv_id() });

    $pub->triage_status_id($status->cvterm_id());

    my $pubprop_types_cv_name = 'PomCur publication property types';

    my $pubprop_types_cv =
      $schema->find_with_type('Cv',
                              { name => $pubprop_types_cv_name });
    my $experiment_type =
      $schema->find_with_type('Cvterm',
                              { name => 'experiment_type',
                                cv_id => $pubprop_types_cv->cv_id() });
    $pub->pubprops()->search({ type_id => $experiment_type->cvterm_id() })
      ->delete();

    for my $exp_type_param ($c->req()->param('experiment-type')) {
      my $pubprop =
        $schema->create_with_type('Pubprop',
                                  { type_id => $experiment_type->cvterm_id(),
                                    value => $exp_type_param,
                                    pub_id => $pub->pub_id() });
    }

    $pub->update();

    $guard->commit();

    $next_pub = _get_next_triage_pub($schema);

    if (defined $next_pub) {
      $c->res->redirect($c->uri_for('/tools/triage'));
      $c->detach();
    } else {
      # fall through
    }
  } else {
    $next_pub = _get_next_triage_pub($schema);
  }

  if (defined $next_pub) {
    $st->{title} = 'Triaging ' . $next_pub->uniquename();
    $st->{pub} = $next_pub;

    $st->{template} = 'tools/triage.mhtml';
  } else {
    $c->flash()->{message} =
      'Triaging finished - no more un-triaged publications';
    $c->res->redirect($c->uri_for('/'));
    $c->detach();
  }
}


=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
