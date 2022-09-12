#!/usr/bin/env perl

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
};

use lib qw(lib);

use Canto::Config;
use Canto::Track;
use Canto::Meta::Util;

my $do_help = 0;
my $lookup_type = undef;
my $ontology_name = undef;
my $verbose = 0;

my $result = GetOptions ("help|h" => \$do_help,
                         "verbose|v" => \$verbose,
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

  warn qq|$0: look up ontology terms in the Canto database in the same way the
autocomplete works.

${message}usage:
   $0 -t <type> [-n ontology-name ] search terms ...

<type> can be "gene" or "ontology"

Examples:

Search for full term name or synonym:
   $0 -t ontology -n fission_yeast_phenotype 'long cells'
Search for word prefix:
   $0 -t ontology -n biological_process 'transpo'
Show more detail
   $0 -v -t ontology -n biological_process 'transpo'
Search for term ID - ontology-name isn't needed
   $0 -t ontology 'FYPO:0000114'
   $0 -v -t ontology 'FYPO:0000114'
Search for gene name or systematic ID
   $0 -t gene 'cdc11'
|;

  exit(1);
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

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();

my $lookup = Canto::Track::get_adaptor($config, $lookup_type);

if (!defined $lookup) {
  usage("no lookup of type: $lookup_type");
}

if ($lookup_type eq 'gene') {
  for my $search_string (@ARGV) {
    my $res = $lookup->lookup([$search_string]);

    for my $gene (@{$res->{found}}) {
      print
        ($gene->{primary_identifier}, "\t",
         $gene->{primary_name} // '', "\t",
         $gene->{product} // '', "\t",
         (join ",", @{$gene->{synonyms}}), "\t",
         $gene->{organism_full_name}, "\t",
         $gene->{organism_taxonid}, "\n");
    }

    if (@{$res->{missing}}) {
      print "Not found:\n";
      for my $identifier (@{$res->{missing}}) {
        print "$identifier\n";
      }
    }
  }
} else {
  if ($lookup_type eq 'ontology') {
    my $search_string = "@ARGV";

    if (!defined $ontology_name && $search_string !~ /^\w+:[\w\d]+$/) {
      usage("no ontology name argument");
    }

    my $res = [];
    my @lookup_args = (ontology_name => $ontology_name,
                       max_results => 20);

    if ($verbose) {
      push @lookup_args, include_children => 1,
        include_synonyms => ['exact', 'broad', 'related'];
    }

    if ($search_string =~ /^\s*:ALL:\s*/) {
      $res = [$lookup->get_all(@lookup_args)];
    } else {

      push @lookup_args, search_string => $search_string;

      $res = $lookup->lookup(@lookup_args);

    }

    for my $hit (@$res) {
      my $synonym_text = '';
      if (defined $hit->{matching_synonym}) {
        $synonym_text =
          q{ (matching synonym: "} . $hit->{matching_synonym} . q{")};
      }
      print $hit->{id}, " - ", $hit->{name}, "$synonym_text\n";

      if ($verbose) {
        print "  synonyms:\n";
        for my $synonym (@{$hit->{synonyms}}) {
          print "    ", $synonym->{name}, " [", $synonym->{type}, "]\n";
        }
        print "  child terms:\n";
        for my $child (@{$hit->{children}}) {
          print "    ", $child->{name}, " (", $child->{id}, ")\n";
        }
      }
    }
  }
}
