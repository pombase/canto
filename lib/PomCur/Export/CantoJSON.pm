package PomCur::Export::CantoJSON;

=head1 NAME

PomCur::Export::CantoJSON - Code to export the contents of the track and
                            curs databases

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Export::CantoJSON

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2011 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;

use PomCur::Track::Serialise;

with 'PomCur::Role::Configurable';
with 'PomCur::Role::Exporter';

=head2 export

 Usage   : my ($count, $json) = $exporter->export($config);
 Function: Return the required TrackDB data and sessions in JSON format
 Args    : $config - a PomCur::Config object
 Return  : (count of sessions exported, JSON format data)

 The options passed to PomCur::Track::Serialise::json() come from the
 parsed_options attribute of Role::Exporter

=cut

sub export
{
  my $self = shift;

  my $config = $self->config();

  my $track_schema = PomCur::TrackDB->new(config => $config);

  return PomCur::Track::Serialise::json($config, $track_schema,
                                        $self->parsed_options());
}

1;
