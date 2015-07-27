package Canto::Role::Exporter;

=head1 NAME

Canto::Role::Exporter - Code for exporting

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Role::Exporter

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

use Moose::Role;
use Carp;
use Getopt::Long qw(GetOptionsFromArray);

use Canto::Curs::State qw/:all/;

=head2 options
 possible options are:
  dump_approved - only return the approved sessions
  export_approved - only return the approved sessions, then mark those sessions
                    as exported
  all_data - return data from all the sessions and all data from the TrackDB,
             including publication and user information
=cut
has options => (is => 'ro', isa => 'ArrayRef', required => 1);

=head2 parsed_options
 This attribute stores the parsed versions of the options attribute.
 Parsed options available are:
  curs_resultset - a TrackDB ResultSet of 'Curs' objects - only these objects
                   are exported
  all_data - return data from all the sessions and all data from the TrackDB,
             including publication and user information
=cut

has parsed_options => (is => 'rw', isa => 'HashRef', init_arg => undef);
has state => (is => 'rw', isa => 'Canto::Curs::State', init_arg => undef);
has track_schema => (is => 'rw', isa => 'Canto::TrackDB', init_arg => undef);
has state_after_export => (is => 'rw', init_arg => undef);

requires 'config';

sub _curs_rs_by_type
{
  my $curs_rs = shift;
  my $session_state = shift;

  return $curs_rs->search({ 'type.name' => 'annotation_status',
                            'cursprops.value' => $session_state,
                            'cv.name' => 'Canto cursprop types', },
                          { join => { cursprops => { type => 'cv' } } })
}

sub BUILD
{
  my $self = shift;

  my @options = @{$self->options()};

  my %parsed_options = ();

  my @opt_config = ('stream-mode!' => \$parsed_options{stream_mode},
                    'all!' => \$parsed_options{all_data},
                    'dump-approved!' => \$parsed_options{dump_approved},
                    'dump-exported!' => \$parsed_options{dump_exported},
                    'export-approved!' => \$parsed_options{export_approved},
                    );
  if (!GetOptionsFromArray(\@options, @opt_config)) {
    die "option parsing failed for: @{$self->options()}\n";
  }

  $self->parsed_options(\%parsed_options);

  $self->state(Canto::Curs::State->new(config => $self->config()));

  if ($parsed_options{export_approved}) {
    $self->state_after_export(EXPORTED)
  }

  my $track_schema = Canto::TrackDB->new(config => $self->config());
  $self->track_schema($track_schema);

  my $curs_rs = $track_schema->resultset('Curs');

  if ($parsed_options{dump_approved} || $parsed_options{export_approved}) {
    $curs_rs = _curs_rs_by_type($curs_rs, 'APPROVED');
  } else {
    if ($parsed_options{dump_exported}) {
      $curs_rs = _curs_rs_by_type($curs_rs, 'EXPORTED');
    } else {
      # default is to export all
    }
  }

  $parsed_options{curs_resultset} = $curs_rs;
}

after 'export' => sub {
  my $self = shift;

  if (defined $self->state_after_export()) {
    my $track_schema = $self->track_schema();

    my $curs_rs =
      $self->parsed_options()->{curs_resultset} // $track_schema->resultset('Curs');
    $curs_rs->reset();

    my @curs_to_update = ();

    while (defined (my $curs = $curs_rs->next())) {
      my $curs_key = $curs->curs_key();
      push @curs_to_update, $curs_key;
    }

    for my $curs_key (@curs_to_update) {
      my $curs_schema = Canto::Curs::get_schema_for_key($self->config(), $curs_key);
      # this writes to the TrackDB, so we need to set the state after we finish
      # iterating with $curs_rs
      $self->state()->set_state($curs_schema, $self->state_after_export());

      $curs_schema->disconnect();
    }
  }
};

1;
