#!/usr/bin/env perl

# Use allele name, description and type to find matching Chado
# alleles.  Then set the allele external_uniquename to be the Chado
# uniquename.
#
# Usage: ./etc/set_ids_from_chado.pl

use strict;
use warnings;
use Carp;

use open ':std', ':encoding(UTF-8)';
use utf8;

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
use Canto::Track;
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
my $track_schema = Canto::TrackDB->new(config => $config);

my $allele_lookup = Canto::Track::get_adaptor($config, 'allele');

my $allele_config = $config->{allele_types};

my $update_count = 0;
my $total_alleles = 0;

my $add_uniquenames = sub {
  my $curs = shift;
  my $curs_key = $curs->curs_key();

  my $curs_schema = shift;
  my $track_schema = shift;

  my $status = $curs->prop_value('annotation_status') // 'UNKNOWN_STATUS';

  my $allele_rs = $curs_schema->resultset('Allele')
    ->search({ external_uniquename => undef });

  ALLELE: while (defined (my $allele = $allele_rs->next())) {
    $total_alleles++;
    my $gene_primary_identifier = $allele->gene()->primary_identifier();

    my $allele_name = ($allele->name() // '*NO_NAME*');
    $allele_name =~ s/^\s+//;
    $allele_name =~ s/\s+$//;
    $allele_name =~ s/Δ|∆/delta/g;
    my $allele_type = $allele->type();
    my $allele_description = $allele->description() // '*NO_DESCRIPTION*';

    if ($allele_type =~ /^wild[ _]type$/) {
      $allele_name = 'wild_type';
      $allele_description = 'wild type';
    }

    my $allele_export_type =
      $allele_config->{$allele_type}->{export_type} //
      $allele_config->{$allele_type =~ s/ /_/gr}->{export_type};

    if (!defined $allele_export_type) {
      if (defined $config->{export_type_to_allele_type}->{$allele_type}) {
        $allele_export_type = $allele_type;
      } else {
        warn "$curs_key: type not found: $gene_primary_identifier ",
          ($allele->{name} // '*NO_NAME*'), " $allele_type $allele_description\n" ;
        next ALLELE;
      }
    }

    my @alleles;

    if ($allele_type eq 'unknown' || $allele_type eq 'disruption') {
      @alleles = $allele_lookup->lookup_by_exact_name($gene_primary_identifier,
                                                      $allele_name);
    } else {
      @alleles = $allele_lookup->lookup_by_details($gene_primary_identifier,
                                                   $allele_export_type,
                                                   $allele_description);

      if (!@alleles) {
        @alleles = $allele_lookup->lookup_by_details($gene_primary_identifier,
                                                     $allele_export_type,
                                                     $allele_description =~ s/, /,/gr);
      }
    }

    if (@alleles > 1) {
      for my $chado_allele (@alleles) {
        if (($chado_allele->{name} // '*NO_NAME*') =~ s/Δ|∆/delta/gr eq $allele_name) {
          my $chado_external_uniquename = $chado_allele->{external_uniquename};
#          warn "$curs_key: found allele for: $gene_primary_identifier ", $allele_name,
#            " $allele_type $allele_description - $chado_external_uniquename\n";

          #    $allele->external_uniquename($chado_external_uniquename);
          #    $allele->update();
          next ALLELE;
        }
      }

      warn "$curs_key: multiple alleles (", scalar(@alleles), ") for: $gene_primary_identifier ",
        $allele_name, " $allele_type $allele_description\n";
      next ALLELE;
    }

    if (@alleles == 0) {
      warn "$curs_key: no alleles found for: $gene_primary_identifier ",
        $allele_name, " $allele_type $allele_description\n";
      next ALLELE;
    }

    my $chado_allele = $alleles[0];
    my $chado_allele_name = $chado_allele->{name} // '*NO_NAME*';
    $chado_allele_name =~ s/Δ|∆/delta/g;

    if ($chado_allele->{type} eq 'wild_type') {
      $chado_allele_name = 'wild_type';
    }

    my $chado_external_uniquename = $chado_allele->{allele_uniquename};

#    warn "$curs_key: found allele for: $gene_primary_identifier ", ($allele_name // "*NO_NAME*"),
#      " $allele_type $allele_description - $chado_external_uniquename\n";

    if ($allele_type ne 'deletion' &&
        $chado_allele_name ne $allele_name) {

      warn $curs_key, q|: Chado allele name doesn't match Canto DB: |,
        "$gene_primary_identifier  allele name: $allele_name  type: ", $allele->type(), "  description: $allele_description -- Chado name: ",
        $chado_allele_name, "\n";
    }

    $update_count++;
#    $allele->external_uniquename($chado_external_uniquename);
#    $allele->update();
  }
};

my $proc = sub {
  Canto::Track::curs_map($config, $track_schema, $add_uniquenames);
};

$track_schema->txn_do($proc);


