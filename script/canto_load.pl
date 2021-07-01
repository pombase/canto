#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Basename;
use IO::All;
use Getopt::Long;
use Fcntl qw(:flock);
use Text::CSV;
use Try::Tiny;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use Canto::Meta::Util;
use Canto::TrackDB;
use Canto::Config;
use Canto::Track;
use Canto::Track::GeneLoad;
use Canto::Track::OntologyLoad;
use Canto::Track::OntologyIndex;
use Canto::Track::LoadUtil;
use Canto::Track::PubmedUtil;
use Canto::Curs::TermUpdate;
use Canto::Config::ExtensionProcess;

my $do_genes = 0;
my $do_pubmed_xml = 0;
my $do_organisms = 0;
my $do_strains = 0;
my $for_taxon = 0;
my @ontology_args = ();
my @delete_ontology_args = ();
my $do_process_extension_config = 0;
my $dry_run = 0;
my $verbose = 0;
my $do_help = 0;

if (@ARGV == 0) {
  usage();
}

my $result = GetOptions ("genes=s" => \$do_genes,
                         "ontology=s" => \@ontology_args,
                         "delete-ontology=s" => \@delete_ontology_args,
                         "organisms=s" => \$do_organisms,
                         "strains=s" => \$do_strains,
                         "process-extension-config" => \$do_process_extension_config,
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
  $0 --organisms organisms_file.csv
or:
  $0 --strains strains_files.csv
or:
  $0 --ontology ontology_file.obo
  $0 --ontology ontology_file.obo --ontology another_ontology.obo
  $0 --ontology http://some_host.org/file.obo
  $0 --process-extension-config --ontology ontology_file.obo --ontology another_ontology.obo
        --delete-ontology "some_ontology_name"
or:
  $0 --pubmed-xml pubmed_entries.xml
or in combination:
  $0 --ontology ontology_2.obo --ontology ontology_2.obo \
     --genes genes_file --for-taxon=<taxon_id>

Options:
  --genes     - load a tab delimited gene data file, must also specify
                the organism with --for-taxon
  --ontology  - load an ontology data file in OBO format
  --delete-ontology - in combination with "--ontology", delete an existing
                      ontology by name
  --pubmed-xml - load publications from a PubMed XML file; only loads
                 publications that aren't already in the database

Any combination of options is valid (eg. genes and ontologies can be
loaded at once) but at most one "--genes" option is allowed.


File formats
~~~~~~~~~~~~

The genes file should have 4 columns, separated by tabs:
  systematic_identifier
  name
  synonyms - comma separated
  product

The ontology files should be in OBO format

The organisms file have 3 columns, separated by commas:
  scientific name (usually "Genus species")
  taxon ID
  common name


Extension config processing
~~~~~~~~~~~~~~~~~~~~~~~~~~~

With the --process-extension-config flag, this script processes the
OBO files with the "owltools" command from the OWLTools package:
https://github.com/owlcollab/owltools

The owltools "--save-closure-for-chado" option is used to calculate
the full transitive closure of the ontologies.

The domain and range IDs for each relation annotation extension
configuration are compared to the owltools output.  A cvtermprop named
"canto_subset" is added to that term in the Canto database and to all
descendant/child terms.  The value of the property is the domain or
range term ID.  This allows us look at any term used in an annotation
and find the sub-ontologies (sub-sets) that it's involved in.

See https://github.com/pombase/canto/wiki/AnnotationExtensionConfig
for more.

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

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

open my $this_script, '<', $0 or die "can't open $0 for reading";
flock($this_script, LOCK_EX) or die "can't get lock on $0";

my $config = Canto::Config::get_config();
my $schema = Canto::TrackDB->new(config => $config);

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
  my $gene_load = Canto::Track::GeneLoad->new(schema => $schema,
                                               organism => $organism);
  print "loading $do_genes\n" if $verbose;

  open my $fh, '<', $do_genes or die "can't open $do_genes: $!";
  $gene_load->load($fh);
  close $fh or die "can't close $do_genes: $!";

  $guard->commit unless $dry_run;
}

if ($do_organisms) {
  my $load_util = Canto::Track::LoadUtil->new(schema => $schema);
  my $guard = $schema->txn_scope_guard;

  open my $fh, '<', $do_organisms or die "can't open $do_organisms: $!";

  my %seen_org_names = ();
  my %seen_taxonids = ();

  while (defined (my $line = <$fh>)) {
    next if $line =~ /Genus|ScientificName/ && $. == 1;

    chomp $line;

    if ($line !~ /,/) {
      warn "line doesn't look comma separated: $line\n";
      next;
    }

    my ($scientific_name, $taxonid, $common_name) =
      map { s/^\s+//; s/\s+$//; $_; } split (/,/, $line);

    if (!defined $taxonid) {
      warn "not enough fields in line: $line\n";
      next;
    }

    $scientific_name =~ s/^\s+//;
    $scientific_name =~ s/\s+$//;
    $scientific_name =~ s/\s+/ /;

    if ($taxonid !~ /^\d+$/) {
      $guard->{inactivated} = 1;
      die qq(load failed - Taxon ID on line $. isn't an integer: $taxonid\n);
    }

    if (exists $seen_org_names{$scientific_name}) {
      $guard->{inactivated} = 1;
      my ($previous_taxonid, $previous_line) = @{$seen_org_names{$scientific_name}};
      if ($previous_taxonid == $taxonid) {
        die "load failed - duplicate scientific name and taxon ID at input lines: "
          . "$. and $previous_line\n";
      } else {
        die "load failed - same scientific name with different taxon ID at lines: "
          . "$. and $previous_line\n";
      }
    }

    if (exists $seen_taxonids{$taxonid}) {
      my ($previous_taxonid, $previous_line) = @{$seen_taxonids{$taxonid}};

      $guard->{inactivated} = 1;
      die "load failed - duplicate taxonid at lines $. and $previous_line\n";
    }

    $seen_org_names{$scientific_name} = [$taxonid, $.];
    $seen_taxonids{$taxonid} = [$scientific_name, $.];

    my $org = $load_util->find_organism_by_taxonid($taxonid);

    if ($org) {
      $org->scientific_name($scientific_name);
      $org->common_name($common_name);
      $org->update();
    } else {
      $load_util->get_organism($scientific_name, $taxonid, $common_name);
    }
  }

  $guard->commit unless $dry_run;
}

if ($do_strains) {
  my $load_util = Canto::Track::LoadUtil->new(schema => $schema);
  my $guard = $schema->txn_scope_guard;

  try {
    $load_util->load_strains($config, $do_strains);
  } catch {
    warn $_;
    $guard->{inactivated} = 1;
    exit 1;
  };

  $guard->commit unless $dry_run;
}

if (@ontology_args) {
  my $index_path = $config->data_dir_path('ontology_index_dir');

  my $index = Canto::Track::OntologyIndex->new(config => $config, index_path => $index_path);
  $index->initialise_index();
  my @relationships_to_load = @{$config->{load}->{ontology}->{relationships_to_load}};

  my $extension_process = undef;

  if ($do_process_extension_config) {
    $extension_process =
      Canto::Config::ExtensionProcess->new(config => $config);
  }

  my $ontology_load = Canto::Track::OntologyLoad->new(schema => $schema,
                                                      config => $config,
                                                      extension_process => $extension_process,
                                                      relationships_to_load => \@relationships_to_load);
  my $synonym_types = $config->{load}->{ontology}->{synonym_types};

  $ontology_load->load([@ontology_args], [@delete_ontology_args], $index, $synonym_types);

  if (!$dry_run) {
    $ontology_load->finalise();
    $index->finish_index();

    my $term_update = Canto::Curs::TermUpdate->new(config => $config);

    my $iter = Canto::Track::curs_iterator($config, $schema);
    while (my ($curs, $cursdb) = $iter->()) {
      $term_update->update_curs_terms($cursdb);
    }
  }
}

if ($do_pubmed_xml) {
  print "loading PubMed XML from $do_pubmed_xml\n" if $verbose;
  my $xml = IO::All->new($do_pubmed_xml)->slurp();
  Canto::Track::PubmedUtil::load_pubmed_xml($schema, $xml,
                                             'admin_load');
}

flock($this_script, LOCK_UN) or die "can't unlock $0";
