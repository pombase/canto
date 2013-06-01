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

use PomCur::Track;
use PomCur::TrackDB;
use PomCur::Meta::Util;
use PomCur::Track::CuratorManager;
use PomCur::Config;


my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}

my $config = PomCur::Config::get_config();
my $track_schema = PomCur::TrackDB->new(config => $config);

my $people_rs = $track_schema->resultset("Person");

my @admin_emails = ();

while (defined (my $person = $people_rs->next())) {
  if ($person->role()->name() eq 'admin') {
    push @admin_emails, $person->email_address();
  }
}

my $curator_manager = PomCur::Track::CuratorManager->new(config => $config);

sub _is_community_curator
{
  my $email = shift;

  return !grep { $_ eq $email } @admin_emails;
}

my $proc = sub {
  my $curs = shift;
  my $curs_schema = shift;
  my $track_schema = shift;

  my $an_rs = $curs_schema->resultset("Annotation");

  print $curs->curs_key(), "\n";

  while (defined (my $an = $an_rs->next())) {
    my $data = $an->data();
    my ($email, $name, $accepted_date) = $curator_manager->current_curator($curs->curs_key());

    if (!defined $email) {
      die "die!";
    }

    if (defined $data->{curator}) {
      if (!defined $data->{curator}->{community_curated}) {
        $data->{curator}->{community_curated} = _is_community_curator($email);
        print "setting community_curated flag\n";
      }
    } else {
      print "storing curator\n";

      $data->{curator}->{name} = $name;
      $data->{curator}->{email} = $email;

      $data->{curator}->{community_curated} = _is_community_curator($email);
    }

    $an->data($data);
    $an->update();
  }
};

my @res = PomCur::Track::curs_map($config, $track_schema, $proc);
