#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Basename;

use Getopt::Long;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use PomCur::Config;
use PomCur::Meta::Util;
use PomCur::TrackDB;
use PomCur::Track;

sub usage
{
  my $message = shift;

  if (defined $message) {
    $message .= "\n";
  } else {
    $message = '';
  }

  die qq|${message}usage:
  $0 [pubmed_ids ...]

Script to remove dead test sessions.
|;
}

my @command_line_pubs = @ARGV;

my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}


my $config = PomCur::Config::get_config();
my $track_schema = PomCur::TrackDB->new(config => $config);

my $iter = PomCur::Track::curs_iterator($config, $track_schema);

my $test_publication_uniquename =
  $config->{test_publication_uniquename};

while (my ($curs, $cursdb) = $iter->()) {
  my $pub = $curs->pub();
  my $pub_uniquename = $pub->uniquename();

  my $curs_key = $curs->curs_key();

  if ($pub_uniquename eq $test_publication_uniquename ||
      $curs_key =~ /^aaaa000\d$/ ||
      grep { $_ eq $pub_uniquename } @command_line_pubs ||
      !defined $curs->corresponding_author()) {
    warn "deleting ", $curs->curs_key(), "\n";
    PomCur::Track::delete_curs($config, $track_schema, $curs_key);
  }
}
