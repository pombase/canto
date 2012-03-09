#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Basename;

use Getopt::Long qw(:config require_order);

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
use PomCur::TrackDB;
use PomCur::Track::Serialise;
use PomCur::Meta::Util;

my $do_help = 0;

my $result = GetOptions ("help|h" => \$do_help);

my %export_modules = (
  dump => 'PomCur::Export::Dump',
);

sub usage
{
  my $types = join "", (map { "   $_\n"; } keys %export_modules);
  die "usage:
   $0 export_type [options]

Possible export types:
$types
";
}

if ($do_help) {
  usage();
}

if (@ARGV < 1) {
  usage();
}

my $export_type = shift;

my @options = @ARGV;

my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}

my $config = PomCur::Config::get_config();

my $export_module = $export_modules{$export_type};

if (defined $export_module) {
  my $exporter =
    eval qq{
require $export_module;
$export_module->new(config => \$config, options => [\@options]);
};
  die "$@" if $@;

  $exporter->export();
} else {
  die "unknown type to export: $export_type\n";
}
