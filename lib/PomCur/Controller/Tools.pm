package PomCur::Controller::Tools;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

PomCur::Controller::Tools - Controller for PomCur user tools

=head1 METHODS

=cut
sub triage :Path {
  my ($self, $c, $arg) = @_;

  my $st = $c->stash();

  $st->{template} = 'tools/triage.mhtml';

  my $schema = $c->schema('track');
  my $config = $c->config();

  my $cv = $schema->find_with_type('Cv',
                                   { name => 'PomCur publication triage status' });
  my $new_cvterm = $schema->find_with_type('Cvterm',
                                           { cv_id => $cv->cv_id(),
                                             name => 'new' });

  my $constraint = {
    status_id => $new_cvterm->cvterm_id()
  };

  my $pub = $schema->resultset('Pub')->search($constraint)->first();

  $st->{title} = 'Triaging ' . $pub->uniquename();

  $st->{pub} = $pub;

  my @statuses = $schema->resultset('Cvterm')->search({ cv_id => $cv->cv_id() });

  $st->{pub_statuses} = [@statuses];
}


=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
