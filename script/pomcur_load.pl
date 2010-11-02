#!/usr/bin/perl -w

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

  push @INC, "lib";
};

use PomCur::Meta::Util;
use PomCur::TrackDB;
use PomCur::Config;
use PomCur::Track::GeneLoad;

my $do_genes = 0;
my $do_ontology = 0;
my $do_help = 0;

my $result = GetOptions ("genes|g=s" => \$do_genes,
                         "ontology|o=s" => \$do_ontology,
                         "help|h" => \$do_help);

sub usage
{
  die "usage:
   $0 --genes genes_file
or:
   $0 --ontology ontology_file.obo

Options:
  -g --genes  - load a tab delimited gene data file
  -o --ontology  - load an ontology data file in OBO format


File formats
~~~~~~~~~~~~

The genes file should have 4 columns, separated by tabs:
  systematic_identifier
  name
  synonyms - comma separated
  product

The ontology file should be in OBO format
";
}

if (!$result || $do_help || ($do_genes && $do_ontology) ||
      !($do_genes || $do_ontology)) {
  usage();
}

if (@ARGV != 0) {
  usage();
}

my $app_name = PomCur::Config::get_application_name();

if (!PomCur::Meta::Util::app_initialised($app_name)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}

if ($do_genes) {
  my $config = PomCur::Config::get_config();
  my $schema = PomCur::TrackDB->new(config => $config);
  my $gene_load = PomCur::Track::GeneLoad->new(schema => $schema);

  my $code = sub {
    $gene_load->load($do_genes);
  };

  $schema->txn_do($code);
}
