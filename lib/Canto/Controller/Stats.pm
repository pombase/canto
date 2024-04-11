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

  my $db_creation_datetime =
    $chado_schema->resultset('Chadoprop')
    ->search({ 'type.name' => 'db_creation_datetime' },
             { join => 'type' })->first()->value();

  chomp $db_creation_datetime;
  $db_creation_datetime =~ s/(\d\d\d\d-\d\d-\d\d).*/$1/;
  $st->{db_creation_datetime} = $db_creation_datetime;

  Canto::Chado::Utils::stats_init($chado_schema, $track_schema);

  my @curation_response_rate =
    Canto::Chado::Utils::curation_response_rate($track_schema);
  $st->{curation_response_rate} = \@curation_response_rate;

  my @annotation_stats = Canto::Chado::Utils::annotation_stats_table($chado_schema, $track_schema);
  $st->{annotation_stats} = \@annotation_stats;

  my @curated_stats = Canto::Chado::Utils::curated_stats($chado_schema, $track_schema);
  $st->{curated_stats} = \@curated_stats;

  my @new_curator_stats = Canto::Chado::Utils::new_curators_per_year($chado_schema);
  $st->{new_curator_stats} = \@new_curator_stats;

  Canto::Chado::Utils::stats_finish($chado_schema, $track_schema);

  $st->{hide_breadcrumbs} = 1;

  $st->{db_creation_datetime} = $db_creation_datetime;

  $st->{title} = "PomBase literature curation statistics - $db_creation_datetime";
  $st->{template} = 'stats/annotation.mhtml';

  if (!$ENV{CANTO_DEBUG}) {
    $c->cache_page(60*60*3-30);  # just under 3 hours
  }
}

1;
