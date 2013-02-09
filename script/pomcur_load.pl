#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Basename;
use IO::All;
use Getopt::Long;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use PomCur::Meta::Util;
use PomCur::TrackDB;
use PomCur::Config;
use PomCur::Track;
use PomCur::Track::GeneLoad;
use PomCur::Track::OntologyLoad;
use PomCur::Track::OntologyIndex;
use PomCur::Track::LoadUtil;
use PomCur::Track::PubmedUtil;
use PomCur::Curs::TermUpdate;

my $do_genes = 0;
my $do_pubmed_xml = 0;
my $for_taxon = 0;
my @ontology_args = ();
my $do_organism = 0;
my $dry_run = 0;
my $verbose = 0;
my $do_help = 0;

if (@ARGV == 0) {
  usage();
}

my $result = GetOptions ("genes=s" => \$do_genes,
                         "ontology=s" => \@ontology_args,
                         "organism=s" => \$do_organism,
                         "pubmed-xml=s" => \$do_pubmed_xml,
                         "for-taxon=i" => \$for_taxon,
                         "verbose|v" => \$verbose,
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
  $0 --genes genes_file --for-taxon=<taxon_id>
or:
  $0 --ontology ontology_file.obo
  $0 --ontology http://some_host.org/file.obo
or:
  $0 --pubmed-xml pubmed_entries.xml
or:
  $0 --organism "<genus> <species> <taxon_id>"
or in combination:
  $0 --organism "<genus> <species> <taxon_id>" \
     --ontology ontology_2.obo --ontology ontology_2.obo \
     --genes genes_file --for-taxon=<taxon_id>

Options:
  --genes     - load a tab delimited gene data file, must also specify
                the organism with --for-taxon
  --ontology  - load an ontology data file in OBO format
  --organism  - add an organism to the database
  --pubmed-xml - load publications from a PubMed XML file; only loads
                 publications that aren't already in the database

Any combination of options is valid (eg. genes and ontologies can be
loaded at once) but at most one "--genes" and at most one "--organism"
option is allowed.

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

if (!$result || $do_help) {
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
  my $taxon_id_type = $schema->find_with_type('Cvterm', { name => 'taxon_id' });
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
  print "loading $do_genes\n" if $verbose;

  open my $fh, '<', $do_genes or die "can't open $do_genes: $!";
  $gene_load->load($fh);
  close $fh or die "can't close $do_genes: $!";

  $guard->commit unless $dry_run;
}

if (@ontology_args) {
  my $guard = $schema->txn_scope_guard;

  my $index_path = $config->data_dir_path('ontology_index_dir');
  my $index = PomCur::Track::OntologyIndex->new(index_path => $index_path);
  $index->initialise_index();
  my $ontology_load = PomCur::Track::OntologyLoad->new(schema => $schema);
  my $synonym_types = $config->{load}->{ontology}->{synonym_types};

  for my $ontology_source (@ontology_args) {
    print "loading $ontology_source\n" if $verbose;
    $ontology_load->load($ontology_source, $index, $synonym_types);
  }

  $guard->commit unless $dry_run;

  my $term_update = PomCur::Curs::TermUpdate->new(config => $config);

  my $iter = PomCur::Track::curs_iterator($config, $schema);
  while (my ($curs, $cursdb) = $iter->()) {
    $term_update->update_curs_terms($curs, $cursdb);
  }
}

if ($do_organism) {
  if ($do_organism =~ /(\S+)\s+(.*?)\s+(\d+)/) {
    my $genus = $1;
    my $species = $2;
    my $taxon_id = $3;

    my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);
    my $guard = $schema->txn_scope_guard;
    print "loading $genus $species - $taxon_id\n" if $verbose;
    $load_util->get_organism($genus, $species, $taxon_id);
    $guard->commit unless $dry_run;
  } else {
    usage "organism option not in the correct format";
  }
}

if ($do_pubmed_xml) {
  print "loading PubMed XML from $do_pubmed_xml\n" if $verbose;
  my $xml = IO::All->new($do_pubmed_xml)->slurp();
  PomCur::Track::PubmedUtil::load_pubmed_xml($schema, $xml,
                                             'admin_load');
}
