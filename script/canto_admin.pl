#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use feature ':5.10';

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
use Canto::TrackDB;
use Canto::Track;
use Canto::Meta::Util;


if (!@ARGV) {
  usage();
}

my $refresh_gene_cache = undef;
my $dry_run = 0;
my $do_help = 0;

my $result = GetOptions ("refresh-gene-cache" => \$refresh_gene_cache,
                         "dry-run|d" => \$dry_run,
                         "help|h" => \$do_help);

sub usage
{
  my $message = shift;

  if (defined $message) {
    $message .= "\n";
  } else {
    $message = '';
  }

  die qq|${message}usage:
  $0 --refresh-gene-cache
This option will update all the name and synonyms for all genes cached by
UniProt::GeneLookup.
|;
}

if ($do_help) {
  usage();
}

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();
my $schema = Canto::TrackDB->new(config => $config);

my $guard = $schema->txn_scope_guard;

my $exit_flag = 1;

my $proc = sub {
  if (defined $refresh_gene_cache) {
    Canto::Track::refresh_gene_cache($config, $schema);

    $exit_flag = 0;
  }
};

$schema->txn_do($proc);

$guard->commit unless $dry_run;

exit $exit_flag;
