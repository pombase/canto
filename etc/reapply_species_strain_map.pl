#!/usr/bin/perl -w

# Lookup the taxon ID associated with each gene in all CursDBs using
# Config::get_species_taxon_of_strain_taxon()
# If the lookup returns a result, change the Organism of the genes
# to the result of the call
# Then also update the organism of the corresponding genes in the TrackDB

###########################
# START OF BOILERPLATE CODE

use strict;
use warnings;
use Carp;
use feature ':5.10';

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
use Canto::TrackDB;
use Canto::Track;
use Canto::Track::LoadUtil;
use Canto::Meta::Util;

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();
my $schema = Canto::TrackDB->new(config => $config);

my $track_schema = Canto::TrackDB->new(config => $config);

# END OF BOILERPLATE CODE
#########################


# A collection of IDs of genes that need to have their organisms
# updated in the TrackDB.  We populate this map while iterating over
# the CursDBs
my %genes_to_update = ();


my $proc = sub {
  my $curs = shift;
  my $curs_schema = shift;
  my $track_schema = shift;

  my $organism_rs = $curs_schema->resultset('Organism');

  # orig taxon ID to new taxon ID map
  my %taxon_map = ();

  # first find all Organisms in this session that need updating,
  # capturing them into %taxon_map
  while (defined (my $organism = $organism_rs->next())) {
    my $orig_taxonid = $organism->taxonid();
    my $lookup_taxonid =
      $config->get_species_taxon_of_strain_taxon($orig_taxonid);

    if (defined $lookup_taxonid && $orig_taxonid != $lookup_taxonid) {
      my $new_org = $curs_schema->resultset('Organism')
        ->find_or_create({ taxonid => $lookup_taxonid });
      $taxon_map{$orig_taxonid} = $new_org;
    }
  }

  my $gene_rs = $curs_schema->resultset('Gene')
    ->search({}, { prefetch => 'organism' });

  # Iterate over genes and update the Organism based on %taxon_map
  while (defined (my $gene = $gene_rs->next())) {
    my $gene_taxonid = $gene->organism()->taxonid();

    my $new_org = $taxon_map{$gene_taxonid};

    if (defined $new_org) {
      $genes_to_update{$gene->primary_identifier()} = 1;

      print "updating ", $gene->primary_identifier(), " in CursDB\n";
      print "  $gene_taxonid -> ", $new_org->taxonid(), "\n";
      $gene->organism($new_org);
      $gene->update();
    }
  }
};

my $load_util = Canto::Track::LoadUtil->new(schema => $schema);


my $txn_proc = sub {
  # iterate over CursDBs
  Canto::Track::curs_map($config, $track_schema, $proc);

  # update organisms of genes in the TrackDB
  for my $gene_primary_identifier (keys %genes_to_update) {
    my $gene = $track_schema->resultset('Gene')
      ->find({ primary_identifier => $gene_primary_identifier },
             { prefetch => 'organism' });
    if (defined $gene) {
      my $props_rs = $gene->organism()->organismprops()->search({}, { prefetch => 'type' });
      my $orig_taxonid;
      while (defined (my $prop = $props_rs->next())) {
        if ($prop->type()->name() eq 'taxon_id') {
          $orig_taxonid = $prop->value();
          last;
        }
      }
      if (!defined $orig_taxonid) {
        die "internal error: can't find taxon ID for $gene_primary_identifier\n";
      }
      my $new_taxonid =
        $config->get_species_taxon_of_strain_taxon($orig_taxonid);
      my $new_organism =
        $load_util->find_organism_by_taxonid($new_taxonid);

      print "updating ", $gene->primary_identifier(), " in TrackDB\n";
      $gene->organism($new_organism);
      $gene->update();
    }
  }
};

$track_schema->txn_do($txn_proc);

exit 0;
