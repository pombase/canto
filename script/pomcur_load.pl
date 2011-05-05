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
use PomCur::Track::OntologyLoad;
use PomCur::Track::OntologyIndex;
use PomCur::Track::LoadUtil;

my $do_genes = 0;
my $for_taxon = 0;
my $do_ontology = 0;
my $do_organism = 0;
my $dry_run = 0;
my $do_help = 0;

my $result = GetOptions ("genes=s" => \$do_genes,
                         "ontology=s" => \$do_ontology,
                         "organism=s" => \$do_organism,
                         "for-taxon=i" => \$for_taxon,
                         "dry-run|T" => \$dry_run,
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
   $0 --genes genes_file --for-taxon=4896
or:
   $0 --ontology ontology_file.obo
or:
   $0 --organism "<genus> <species> <taxon_id>"
Options:
  --genes  - load a tab delimited gene data file, must be also specify the
                organism with --for-taxon
  --ontology  - load an ontology data file in OBO format
  --organism  - add an organism to the database

File formats
~~~~~~~~~~~~

The genes file should have 4 columns, separated by tabs:
  systematic_identifier
  name
  synonyms - comma separated
  product

The ontology file should be in OBO format
|;
}

if (!$result || $do_help || !($do_genes xor $do_ontology xor $do_organism)) {
  usage();
}

if ($do_genes && !$for_taxon) {
  usage("--for-taxon must be specified when using --genes");
}

if (@ARGV != 0) {
  usage();
}

my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}

my $config = PomCur::Config::get_config();
my $schema = PomCur::TrackDB->new(config => $config);

if ($do_genes) {
  my $taxon_id = $for_taxon;
  my $taxon_id_type = $schema->find_with_type('Cvterm', { name => 'taxonId' });
  my $organism =
    $schema->resultset('Organismprop')
       ->search({ value => $taxon_id, type_id => $taxon_id_type->cvterm_id() })
       ->search_related('organism')->single();

  if (!defined $organism) {
    usage "no organism found for taxon ID: $taxon_id";
  }

  my $guard = $schema->txn_scope_guard;
  my $gene_load = PomCur::Track::GeneLoad->new(schema => $schema,
                                               organism => $organism);
  $gene_load->load($do_genes);
  $guard->commit unless $dry_run;
}

if ($do_ontology) {
  my $guard = $schema->txn_scope_guard;
  my $index = PomCur::Track::OntologyIndex->new(config => $config);
  $index->initialise_index();
  my $ontology_load = PomCur::Track::OntologyLoad->new(schema => $schema);
  $ontology_load->load($do_ontology, $index);
  $guard->commit unless $dry_run;
}

if ($do_organism) {
  if ($do_organism =~ /(\S+)\s+(.*?)\s+(\d+)/) {
    my $genus = $1;
    my $species = $2;
    my $taxon_id = $3;

    my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);
    my $guard = $schema->txn_scope_guard;
    $load_util->get_organism($genus, $species, $taxon_id);
    $guard->commit unless $dry_run;
  } else {
    usage "organism option not in the correct format";
  }
}
