package Canto::Track::Serialise;

=head1 NAME

Canto::Track::Serialise - Code for serialising and de-serialising a TrackDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::Serialise

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;

use JSON;

use Canto::Curs::Serialise;

sub _get_cursprops
{
  my $curs = shift;

  my $rs = $curs->cursprops();
  my @ret = ();

  while (defined (my $prop = $rs->next())) {
    push @ret, {
      type => $prop->type()->name(),
      value => $prop->value(),
    };
  }

  return \@ret;
}

sub _get_curation_sessions
{
  my $config = shift;
  my $schema = shift;
  my $options = shift;

  my %ret_map = ();

  my $curs_rs = $options->{curs_resultset} // $schema->resultset('Curs');

  while (defined (my $curs = $curs_rs->next())) {
    my $curs_key = $curs->curs_key();
    my $data;
    if ($options->{stream_mode}) {
      $data = undef;
    } else {
      $data = Canto::Curs::Serialise::perl($config, $schema, $curs_key, $options);
      my $props = _get_cursprops($curs);

      for my $prop_data (@$props) {
        my $prop_type = $prop_data->{type};

        if (exists $data->{metadata}->{$prop_type}) {
          my $new = $prop_data->{value};

          if ($prop_type =~ /_date$/ &&
              $data->{metadata}->{$prop_type} =~ /^\d\d\d\d-\d\d-\d\d/ &&
              ($data->{metadata}->{$prop_type} cmp $new) < 0) {
            # use the most recent date
            $data->{metadata}->{$prop_type} = $new;
          } else {
            if ($data->{metadata}->{$prop_type} ne $new) {
              warn "overwrite data from curs with: ", $prop_data->{type},
                " from the TrackDB\n";
            }
          }
        } else {
          $data->{metadata}->{$prop_type} = $prop_data->{value};
        }
      }
    }

    $ret_map{$curs_key} = $data;
  }

  return \%ret_map;
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
      corresponding_author => _get_name($pub->corresponding_author()),
      triage_status => _get_name($pub->triage_status()),
      properties => _get_pubprops($pub),
      curation_statuses => _get_pub_curation_statuses($pub),
    );
    if ($options->{all_data}) {
      $pub_hash{title} = $pub->title();
      $pub_hash{abstract} = $pub->abstract();
      $pub_hash{authors} = $pub->authors();
      $pub_hash{affiliation} = $pub->affiliation();
      $pub_hash{authors} = $pub->authors();
      $pub_hash{publication_date} = $pub->publication_date();
      $pub_hash{citation} = $pub->citation();
    }
    $ret{$pub->uniquename()} = { %pub_hash };
  }

  return \%ret;
}

sub _get_people
{
  my $schema = shift;

  my $rs = $schema->resultset('Person');
  my %ret = ();

  while (defined (my $person = $rs->next())) {
    $ret{$person->email_address()} = {
      name => $person->name(),
      role => $person->role()->name(),
      lab => defined $person->lab() ? $person->lab()->name() : undef,
      password => $person->password(),
    };
  }

  return \%ret;
}

sub _get_labs
{
  my $schema = shift;

  my $rs = $schema->resultset('Lab');
  my %ret = ();

  while (defined (my $lab = $rs->next())) {
    $ret{$lab->name()} = {
      head => $lab->lab_head()->name(),
    };
  }

  return \%ret;
}

=head2 json

 Usage   : my $ser = Canto::Track::Serialise::json
 Function: Return a JSON representation of the TrackDB and all its CursDBs
 Args    : $config - a Config object
           $schema - the TrackDB
           $options - a hash of settings
#             - stream_mode => (0|1) - if 1, change the behaviour to
#                 return two things: the JSON for the TrackDB and an
#                 iterator returning the JSON representation of each
#                 CursDB in turn - default 1
             - all_data => (0|1) - if 1, include all data from the TrackDB,
                 including publications and users.  If 0, just return the
                 sessions
             - curs_resultset - A ResultSet of the Curs (curation sessions)
                 to export.  Defaults to all sessions.

 Returns : A JSON string containing all of the TrackDB and CursDB data
           or with stream_mode set, return a (JSON string, CursDB JSON
           iterator) pair.

=cut
sub json
{
  my $config = shift;
  my $schema = shift;
  my $options = shift;

  my $curation_sessions_hash =
    _get_curation_sessions($config, $schema, $options);

  my $hash;

  if ($options->{all_data}) {
    $hash = {
      curation_sessions => $curation_sessions_hash,
      publications => _get_pubs($schema, $options),
      people => _get_people($schema),
      labs => _get_labs($schema),
    };
  } else {
    $hash = {
      curation_sessions => $curation_sessions_hash
    };
  }

  my $encoder = JSON->new()->pretty(1)->canonical(1);

  my $curs_count = scalar(keys(%{$hash->{curation_sessions}}));

  return ($curs_count, $encoder->encode($hash));
}

1;
