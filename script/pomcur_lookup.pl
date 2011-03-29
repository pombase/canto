#!/usr/bin/perl -w

use strict;
use warnings;
use Carp;
use File::Basename;
use Getopt::Long;
use Try::Tiny;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }

  push @INC, "lib";
};

use PomCur::Config;
use PomCur::Track;
use PomCur::Meta::Util;

my $do_help = 0;
my $lookup_type = undef;
my $ontology_name = undef;

my $result = GetOptions ("help|h" => \$do_help,
                         "lookup-type|t:s" => \$lookup_type,
                         "ontology-name|n:s" => \$ontology_name);

sub usage
{
  my $message = shift;

  if (defined $message) {
    $message .= "\n";
  } else {
    $message = '';
  }

  die "${message}usage:
   $0 --lookup-type
";
}

if ($do_help) {
  usage();
}

if (!defined $lookup_type) {
  usage("no look up type specified");
}

if (@ARGV == 0) {
  usage("must have at least one argument to lookup");
}

my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}

my $config = PomCur::Config::get_config();

my $lookup;

try {
  $lookup = PomCur::Track::get_adaptor($config, $lookup_type);
} catch {
  usage("no lookup of type: $lookup_type");
};

if ($lookup_type eq 'gene') {
  my $res = $lookup->lookup([@ARGV]);

  # TODO
} else {
  if ($lookup_type eq 'ontology') {
    if (!defined $ontology_name) {
      usage("no ontology name argument");
    }

    my $search_string = $ARGV[0];

    my $res = $lookup->web_service_lookup(ontology_name => $ontology_name,
                                          search_string => $search_string);

    for my $hit (@$res) {
      print $hit->{id}, " - ", $hit->{name}, "\n";
    }
  }
}
