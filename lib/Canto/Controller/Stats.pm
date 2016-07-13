package Canto::Controller::Stats;

=head1 NAME

Canto::Controller::Stats - Public statistics pages

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Controller::Stats

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use parent 'Catalyst::Controller';

use Moose;

=head2 /stats/annotation

 Function: Make a table of annotation statistics from Chado

=cut

sub annotation : Local {
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $config = $c->config();
  my $chado_schema = Canto::ChadoDB->new(config => $config);

  my $track_schema = $c->schema('track');

  my @per_pub_stats = Canto::Chado::Utils::per_publication_stats($chado_schema, $track_schema);
  $st->{per_pub_stats_table} = \@per_pub_stats;

  my @stats = Canto::Chado::Utils::annotation_stats_table($chado_schema, $track_schema);
  $st->{stats_table} = \@stats;

  $st->{title} = "Annotation statistics";
  $st->{template} = 'stats/annotation.mhtml';
}

1;
