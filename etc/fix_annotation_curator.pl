#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use Canto::Track;
use Canto::TrackDB;
use Canto::Meta::Util;
use Canto::Track::CuratorManager;
use Canto::Config;
use Canto::Curs::State;


my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();
my $track_schema = Canto::TrackDB->new(config => $config);

my $people_rs = $track_schema->resultset("Person");

my @admin_emails = ();

while (defined (my $person = $people_rs->next())) {
  if ($person->role()->name() eq 'admin') {
    push @admin_emails, $person->email_address();
  }
}

my $curator_manager = Canto::Track::CuratorManager->new(config => $config);

sub _is_community_curator
{
  my $email = shift;

  if (grep { $_ eq $email } @admin_emails) {
    return 0;
  } else {
    return 1;
  }
}

my $state = Canto::Curs::State->new(config => $config);

my $proc = sub {
  my $curs = shift;
  my $curs_schema = shift;
  my $track_schema = shift;

  my $an_rs = $curs_schema->resultset("Annotation");

  warn $curs->curs_key(), "\n";

  my ($email, $name, $known_as, $accepted_date) =
    $curator_manager->current_curator($curs->curs_key());

  my ($current_state, $submitter, $gene_count, $datestamp) =
    $state->get_state($curs_schema);

  my $new_datestamp = $datestamp;

  while (defined (my $an = $an_rs->next())) {
    my $data = $an->data();

    if (defined $data->{curator}) {
      $data->{curator}->{community_curated} = _is_community_curator($email);
      warn "setting community_curated flag\n";
    } else {
      warn "storing curator in annotation ", $an->annotation_id(), "\n";

      $data->{curator}->{name} = $name;
      $data->{curator}->{email} = $email;

      $data->{curator}->{community_curated} = _is_community_curator($email);
    }

    if ($current_state eq Canto::Curs::State::CURATION_IN_PROGRESS) {
      if (!defined $new_datestamp) {
        $new_datestamp = $an->creation_date();
      } else {
        if ($new_datestamp gt $an->creation_date()) {
          $new_datestamp = $an->creation_date();
        }
      }
    }
  $an->data($data);
    $an->update();
  }

  if (!defined $datestamp) {
    if (!defined $new_datestamp) {
      $new_datestamp =
        $state->get_metadata($curs_schema,
                             Canto::Curs::State::ACCEPTED_TIMESTAMP_KEY());
    }
    if (defined $new_datestamp) {
      $state->set_metadata($curs_schema,
                           Canto::Curs::State::CURATION_IN_PROGRESS_TIMESTAMP_KEY(),
                           $new_datestamp);
      warn "setting new date for curation_in_progress: $new_datestamp\n";
    }
  }

  if ($accepted_date) {
    $state->set_metadata($curs_schema,
                         Canto::Curs::State::ACCEPTED_TIMESTAMP_KEY(),
                         $accepted_date);
    warn "setting new date for the accepted timestamp: $accepted_date\n";
  }
};

my @res = Canto::Track::curs_map($config, $track_schema, $proc);
