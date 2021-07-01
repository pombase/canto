#!/usr/bin/env perl

# example script to change an annotation type
# See: https://github.com/pombase/canto/issues/2366

use strict;
use warnings;
use Carp;

use File::Basename;


BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    chdir "..";
  }
};

use lib qw(lib);

use Canto::Config;
use Canto::TrackDB;
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


my $old_annotation_type = 'pathogen_host_interaction_phenotype';
my $new_annotation_type = 'gene_for_gene_phenotype';

my $needed_extension_relation = 'gene_for_gene_interaction';

my $proc = sub {
  my $curs = shift;
  my $cursdb = shift;

  my $annotation_rs = $cursdb->resultset('Annotation');

  while (defined (my $annotation = $annotation_rs->next())) {
    next unless $annotation->type() eq $old_annotation_type;

    my $data = $annotation->data();
    my $extension = $data->{extension};

    my $found_extension = 0;

    if (defined $extension) {
      map {
        my $or_part = $_;
        map {
          my $and_part = $_;
          if ($and_part->{rangeType} && $and_part->{rangeType} eq 'Ontology' &&
                $and_part->{relation} eq $needed_extension_relation ) {
            print $and_part->{relation}, "\n";
            $found_extension = 1;
          }
        } @$or_part;
      } @$extension;
    }

    if ($found_extension) {
      print "changing type of annotation in session: ", $curs->curs_key(), "\n";
      $annotation->type($new_annotation_type);
      $annotation->update();
    }
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);
