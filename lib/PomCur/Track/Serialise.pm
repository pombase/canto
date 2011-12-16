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
  my $options = shift;

  my @curs_list = $schema->resultset('Curs')->all();

  return {
    map {
      my $curs_key = $_->curs_key();
      my $data;
      if ($options->{stream_mode}) {
        $data = undef;
      } else {
        my $cursdb = PomCur::Curs::get_schema_for_key($config, $curs_key);
        $data = PomCur::Curs::Serialise::perl($cursdb, $options);
      }
      ($curs_key, $data);
    } @curs_list
  };
}

sub _get_name
{
  my $obj = shift;

  if (defined $obj) {
    return $obj->name();
  } else {
    return undef;
  }
}

sub _get_pubprops
{
  my $pub = shift;

  my $rs = $pub->pubprops();
  my @ret = ();

  while (defined (my $prop = $rs->next())) {
    push @ret, {
      type => $prop->type()->name(),
      value => $prop->value(),
    };
  }

  return \@ret;
}

sub _get_pub_curation_statuses
{
  my $pub = shift;

  my $rs = $pub->pub_curation_statuses();
  my @ret = ();

  while (defined (my $status = $rs->next())) {
    push @ret, {
      status => $status->status()->name(),
      value => $status->value(),
    };
  }

  return \@ret;
}

sub _get_pubs
{
  my $schema = shift;
  my $options = shift;

  my $rs = $schema->resultset('Pub');
  my %ret = ();

  while (defined (my $pub = $rs->next())) {
    my %pub_hash = (
      type => $pub->type()->name(),
      assigned_curator => _get_name($pub->assigned_curator()),
      triage_status => _get_name($pub->triage_status()),
      properties => _get_pubprops($pub),
      curation_statuses => _get_pub_curation_statuses($pub),
    );
    if ($options->{dump_all}) {
      $pub_hash{title} = $pub->title();
      $pub_hash{abstract} = $pub->abstract();
      $pub_hash{authors} = $pub->authors();

    }
    $ret{$pub->uniquename()} = { %pub_hash };
  }

  return \%ret;
}

=head2 json

 Usage   : my $ser = PomCur::Track::Serialise::json
 Function: Return a JSON representation of the TrackDB and all its CursDBs
 Args    : $config - a Config object
           $schema - the TrackDB
           $options - a hash of settings
             - stream_mode => (0|1) - if 1, change the behaviour to
                 return two things: the JSON for the TrackDB and an
                 iterator returning the JSON representation of each
                 CursDB in turn - default 1
             - dump_all => (0|1) - if 1, dump all data from the
                 track and curs databases, including data that can be
                 recreated (eg. publication title can be found from
                 PubMed ID) - default 0
 Returns : A JSON string containing all of the TrackDB and CursDB data
           or with stream_mode set, return a (JSON string, CursDB JSON
           iterator) pair.

=cut
sub json
{
  my $config = shift;
  my $schema = shift;
  my $options = shift;

  my ($curation_sessions_hash, $sessions_iter) =
    _get_curation_sessions($config, $schema, $options);

  my $track_hash = {
    curation_sessions => $curation_sessions_hash,
    publications => _get_pubs($schema, $options),
  };

  my $encoder = JSON->new()->utf8()->pretty(1)->canonical(1);

  return $encoder->encode($track_hash);
}

1;
