package Canto::Export::CantoJSON;

=head1 NAME

Canto::Export::CantoJSON - Code to export the contents of the track and
                            curs databases

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Export::CantoJSON

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2011-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;

use Canto::Track::Serialise;

with 'Canto::Role::Configurable';
with 'Canto::Role::Exporter';

=head2 export

 Usage   : my ($count, $json) = $exporter->export($config);
 Function: Return the required TrackDB data and sessions in JSON format
 Args    : $config - a Canto::Config object
 Return  : (count of sessions exported, JSON format data)

 The options passed to Canto::Track::Serialise::json() come from the
 parsed_options attribute of Role::Exporter

=cut

sub export
{
  my $self = shift;

  my $config = $self->config();

  my $track_schema = Canto::TrackDB->new(config => $config);

  my @serialise_result = Canto::Track::Serialise::json($config, $track_schema,
                                                       $self->parsed_options());

  my $exported_session_keys = $serialise_result[2];

  @{$self->exported_session_keys()} = @$exported_session_keys;

  return ($serialise_result[0], $serialise_result[1]);
}

1;
