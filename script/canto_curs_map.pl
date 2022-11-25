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

use Canto::Config;
use Canto::Track;
use Canto::TrackDB;
use Canto::Meta::Util;

my $do_help = 0;

if (!@ARGV) {
  usage();
}

if ($ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
  usage();
}

my $use_transaction = 1;

if (@ARGV > 0 and $ARGV[0] eq '--no-transaction') {
  $use_transaction = 0;
  shift;
}

if (@ARGV == 0) {
  usage("Not enough arguments");
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
  $0 --no-transaction 'Perl code'
or
  $0 -
  (to read code from STDIN)
or
  $0 -h (or --help)
to get this message

The Perl code will be eval()ed for each curs.  The variables \$curs
and \$curs_schema will be available to the code.  \$curs is a
Canto::TrackDB::Curs object, \$curs_schema is a Canto::CursDB object
and \$track_schema is a TrackDB object.  The Canto::Config object is
also available as \$config.  Example; print the curs_key and gene
count for each curs DB:

$0 'print \$curs->curs_key(), " ", \$curs_schema->resultset("Gene")->count(), "\\n"'

The TrackDB will locked due while the command is running unless the
"--no-transaction" flag is passed.
|;
}

my $code;

if ($ARGV[0] eq '-') {
  local $/ = undef;
  $code = <>;
} else {
  $code = $ARGV[0];
}

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();
my $track_schema = Canto::TrackDB->new(config => $config);

my $user_proc = sub {
  my $curs = shift;
  my $curs_key = $curs->curs_key();
  my $curs_schema = shift;
  my $track_schema = shift;

  eval $code;
  if ($@) {
    die "error while executing use code: $@\n";
  }
};

my $proc = sub {
  Canto::Track::curs_map($config, $track_schema, $user_proc);
};

if ($use_transaction) {
  $track_schema->txn_do($proc);
} else {
  $proc->();
}
