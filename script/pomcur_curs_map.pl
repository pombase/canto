#!/usr/bin/env perl

use strict;
use warnings;
use Carp;

use File::Basename;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use PomCur::Config;
use PomCur::Track;
use PomCur::TrackDB;
use PomCur::Meta::Util;

my $do_help = 0;

if (!@ARGV) {
  usage();
}

if ($ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
  usage();
}

if (@ARGV != 1) {
  usage("Needs exactly one argument\n");
}

sub usage
{
  my $message = shift;

  if (defined $message) {
    $message .= "\n";
  } else {
    $message = '';
  }

  die qq|${message}usage:
  $0 'Perl code'
or
  $0 -h (or --help)
to get this message

The Perl code will be eval()ed for each curs.  The variables \$curs
and \$curs_schema will be available to the code.  \$curs is a
PomCur::TrackDB::Curs object and \$curs_schema is a PomCur::CursDB
object.  The PomCur::Config object is also available as \$config.

Example; print the curs_key and gene count for each curs DB:

$0 'print \$curs->curs_key(), " ", \$curs_schema->resultset("Gene")->count(), "\\n"'
|;
}


my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}

my $config = PomCur::Config::get_config();
my $track_schema = PomCur::TrackDB->new(config => $config);

my $user_proc = sub {
  my $curs = shift;
  my $curs_schema = shift;

  eval $ARGV[0];
  if ($@) {
    die "error while executing use code: $@\n";
  }
};

my $proc = sub {
  PomCur::Track::curs_map($config, $track_schema, $user_proc);
};

$track_schema->txn_do($proc);
