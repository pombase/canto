package PomCur::Track::Serialise;

=head1 NAME

PomCur::Track::Serialise - Code for serialising and de-serialising a TrackDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::Serialise

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

use JSON;

use PomCur::Curs::Serialise;


sub _get_curation_sessions
{
  my $config = shift;
  my $schema = shift;

  my @curs_list = $schema->resultset('Curs')->all();

  return [
    map {
      my $cursdb = PomCur::Curs::get_schema_for_key($config, $_->curs_key);
      PomCur::Curs::Serialise::perl($cursdb);
    } @curs_list
  ];
}

=head2 json

 Usage   : my $ser = PomCur::Track::Serialise::json
 Function: Return a JSON representation of the TrackDB and all its CursDBs
 Args    : $schema - the TrackDB
 Returns : A JSON string

=cut
sub json
{
  my $config = shift;
  my $schema = shift;

  my $track_hash = {
    curation_sessions => _get_curation_sessions($config, $schema),
  };

  my $encoder = JSON->new()->utf8()->pretty(1);

  return $encoder->encode($track_hash);
}

1;
