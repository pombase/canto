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

use Canto::Config;
use Canto::Meta::Util;
use Canto::TrackDB;
use Canto::Track;

sub usage
{
  my $message = shift;

  if (defined $message) {
    $message .= "\n";
  } else {
    $message = '';
  }

  die qq"${message}usage:
  $0

Checks and possibly fixes inconsistencies in the database.

Current checks:
  - the PMID in the cursdb metadata table should match the PMID in the
    trackdb for that curs
  - the curs_key stored in the metadata table matches the curs_key
    in the Track DB
  - make sure that all Alleles have a primary_identifier
  - remove alleles that aren't part of a genotype
";
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

my $iter = Canto::Track::curs_iterator($config, $track_schema);

while (my ($curs, $cursdb) = $iter->()) {
  my $pub = $curs->pub();
  my $pub_uniquename = $pub->uniquename();

  my @res = Canto::Track::validate_curs($config, $track_schema, $curs);

  if (@res) {
    my $curs_key = $curs->curs_key();
    print "$curs_key:\n";
    for my $mess (@res) {
      print "  $mess\n";
    }
  }

  $cursdb->disconnect();
}
