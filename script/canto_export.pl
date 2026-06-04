#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Basename;

use open ':std', ':encoding(UTF-8)';

use Getopt::Long qw(:config require_order);

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }

  push @INC, "lib";
};

use Canto::Config;
use Canto::Track;
use Canto::TrackDB;
use Canto::Track::Serialise;
use Canto::Meta::Util;

my $do_help = 0;
my $verbose = 0;

my $result = GetOptions ("help|h" => \$do_help,
                         "verbose|v" => \$verbose);

my %export_modules = (
  'canto-json' => 'Canto::Export::CantoJSON',
  'gaf' => 'Canto::Export::GeneAssociationFile',
  'tab-zip' => 'Canto::Export::TabZip',
  'allele-table' => 'Canto::Export::AlleleTable',
  'pubs-table' => 'Canto::Export::PubsTable',
);

sub usage
{
  my $types = join "", (map { "   $_\n"; } keys %export_modules);
  die "usage:
   $0 [-v] [-u] export_type [options]

options:
  -v
     verbose output

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

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();

my $export_module = $export_modules{$export_type};

if (defined $export_module) {
  my $exporter =
    eval qq{
require $export_module;
$export_module->new(config => \$config, options => [\@options]);
};
  die "$@" if $@;

  my ($count, $results) = $exporter->export();

  if ($verbose) {
    if ($count > 0) {
      warn "$count sessions exported\n";
    } else {
      warn "no sessions exported\n";
    }
  }

  print $results, "\n";
} else {
  die "unknown type to export: $export_type\n";
}
