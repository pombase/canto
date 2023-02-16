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

my %cursprops_cache = ();

sub _get_cursprops
{
  my $track_schema = shift;
  my $curs = shift;
  my $options = shift;

  if (keys %cursprops_cache == 0) {
    my $rs = $track_schema->resultset('Cursprop')
      ->search({}, { prefetch => ['type', 'curs'] });

    while (defined (my $prop = $rs->next())) {
      my $prop_type_name = $prop->type()->name();

      if (!$options->{export_curator_names} &&
          $prop_type_name eq 'approver_name') {
        next;
      }

      push @{$cursprops_cache{$prop->curs()->curs_key()}},
        {
          type => $prop_type_name,
          value => $prop->value(),
        };
    }
  }

  return $cursprops_cache{$curs->curs_key} // [];
}

sub _get_curation_sessions
{
  my $config = shift;
  my $schema = shift;
  my $options = shift;

  my %ret_map = ();

  my $curs_rs = $options->{curs_resultset} //
    $schema->resultset('Curs')->search({}, { prefetch => { pub => 'triage_status' }});

  while (defined (my $curs = $curs_rs->next())) {
    my $curs_key = $curs->curs_key();

    my $props = _get_cursprops($schema, $curs, $options);

    my $curs_status = undef;

    for my $prop (@$props) {
      if ($prop->{type} eq 'annotation_status') {
        $curs_status = $prop->{value};
      }
    }

    my $triage_status_name = $curs->pub()->triage_status()->name();

    next unless
      (grep {
        $_ eq $triage_status_name;
      } @{$config->{export}->{canto_json}->{pub_triage_status_to_export}}) ||
      $curs_status eq 'APPROVED';

    my $data;
    if ($options->{stream_mode}) {
      $data = undef;
    } else {
      $data = Canto::Curs::Serialise::perl($config, $schema, $curs_key, $options,
                                           $curs_status);

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

my %pubprops_cache = ();

sub _get_pubprops
{
  my $track_schema = shift;
  my $pub = shift;

  if (keys %pubprops_cache == 0) {

    my $rs = $track_schema->resultset('Pubprop')
      ->search({}, { prefetch => ['type', 'pub' ] });

    while (defined (my $prop = $rs->next())) {
      push @{$pubprops_cache{$prop->pub()->uniquename()}}, {
        type => $prop->type()->name(),
        value => $prop->value(),
      };
    }
  }

  return $pubprops_cache{$pub->uniquename()} // [];
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
  my $config = shift;
  my $schema = shift;
  my $options = shift;

  my $rs = $schema->resultset('Pub')->search({}, { prefetch => 'triage_status' });
  my %ret = ();

  while (defined (my $pub = $rs->next())) {
    my $pubprops = _get_pubprops($schema, $pub);

    my $curs_status = undef;

  CURS:
    for my $curs ($pub->curs()->all()) {
      my $props = _get_cursprops($schema, $curs);

      for my $prop (@$props) {
        if ($prop->{type} eq 'annotation_status') {
          $curs_status = $prop->{value};
          last CURS;
        }
      }
    }

    my $triage_status_name = $pub->triage_status()->name();

    next unless
      (grep {
        $_ eq $triage_status_name;
      } @{$config->{export}->{canto_json}->{pub_triage_status_to_export}}) ||
      $curs_status && $curs_status eq 'APPROVED';

    my %pub_hash = (
      type => $pub->type()->name(),
      corresponding_author => _get_name($pub->corresponding_author()),
      triage_status => _get_name($pub->triage_status()),
      properties => $pubprops,
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
      $pub_hash{added_date} = $pub->added_date();
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
      orcid => $person->orcid(),
      lab => defined $person->lab() ? $person->lab()->name() : undef,
      orcid => $person->orcid(),
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
      publications => _get_pubs($config, $schema, $options),
    };
  } else {
    $hash = {
      curation_sessions => $curation_sessions_hash
    };
  }

  $hash->{schema_version} = 1;

  my $encoder = JSON->new()->pretty(1)->canonical(1);

  my $curs_count = scalar(keys(%{$hash->{curation_sessions}}));

  my @exported_session_keys = grep {
    my $session_key = $_;
    my $annotation_status =
      $hash->{curation_sessions}->{$session_key}->{metadata}->{annotation_status};
    $annotation_status eq 'APPROVED';
  } keys(%{$hash->{curation_sessions}});

  return ($curs_count, $encoder->encode($hash), \@exported_session_keys);
}

1;
