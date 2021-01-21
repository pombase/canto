#!/usr/bin/perl -w

# iterate over gene expression annotations and then
# replace terms from the PomGeneEx namespace with more specific terms from
# the PomGeneExProt or PomGeneExRNA namespaces
# See: https://github.com/pombase/website/issues/1637

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

my $lookup = Canto::Track::get_adaptor($config, 'ontology');


my $proc = sub {
  my $curs = shift;
  my $curs_schema = shift;
  my $track_schema = shift;

  my $annotation_rs = $curs_schema->resultset('Annotation')
    ->search({ -or => [
      { type => 'wt_rna_expression'},
      { type => 'wt_protein_expression' }
    ]});

  while (defined (my $annotation = $annotation_rs->next())) {
    my $type = $annotation->type();

    my $data = $annotation->data();

    my $term_ontid = $data->{term_ontid};

    if (!defined $term_ontid) {
      use Data::Dumper;
      die Dumper([$term_ontid, $data]);
    }

    my $term = $lookup->lookup_by_id(id => $term_ontid);

    my $type_prefix;
    my $namespace;
    if ($type eq 'wt_rna_expression') {
      $type_prefix = 'RNA';
      $namespace = 'PomGeneExRNA';
    } else {
      $type_prefix = 'protein';
      $namespace = 'PomGeneExProt';
    }

    my $new_term_details;

    my $results = $lookup->lookup(ontology_name => $namespace,
                                  search_string => "$type_prefix " . $term->{name});

    if (@$results > 0 &&
      $results->[0]->{name} eq "$type_prefix " . $term->{name}) {
      $new_term_details = $results->[0];
    }

    if (!$new_term_details) {
      $results = $lookup->lookup(ontology_name => $namespace,
                                 search_string => "$type_prefix level " . $term->{name});

      if (@$results > 0 &&
            $results->[0]->{name} eq "$type_prefix level " . $term->{name}) {
        $new_term_details = $results->[0];
      }
    }

    if (!$new_term_details) {
      die "can't find new term for ", $term->{name}, " in ", $namespace;
    }

    $data->{term_ontid} = $new_term_details->{id};
    $annotation->data($data);
    $annotation->update();
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);

exit 0;
