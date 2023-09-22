#!/usr/bin/env perl

# for each allele in APPROVED sessions, look it up in Chado then use
# the Chado details to fill in missing Canto allele details

use strict;
use warnings;
use Carp;

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

push @{$config->{export_type_to_allele_type}->{nonsense_mutation}}, { name => 'nonsense mutation' };

my $track_schema = Canto::TrackDB->new(config => $config);

my $allele_lookup = Canto::Track::get_adaptor($config, 'allele');
my $gene_lookup = Canto::Track::get_adaptor($config, 'gene');

my $allele_config = $config->{allele_types};

my $_gene_from_chado = sub {
  my $primary_identifier = shift;

  my $res = $gene_lookup->lookup([$primary_identifier]);

  my $found = $res->{found};

  if (!$found) {
    return undef;
  }

  my @found_genes = grep {
    $_->{primary_identifier} eq $primary_identifier;
  } @{$found};

  if (@found_genes > 1) {
    croak "internal error: lookup returned more than one gene for " .
      $primary_identifier;
  }

  if (@found_genes == 0) {
    croak "lookup failed for gene: $primary_identifier";
  }

  return $found_genes[0];
};

my $add_proc = sub {
  my $curs = shift;
  my $curs_key = $curs->curs_key();
  my $curs_schema = shift;
  my $track_schema = shift;

  my $status = $curs->prop_value('annotation_status') // 'UNKNOWN_STATUS';

  my $allele_rs = $curs_schema->resultset('Allele');

 ALLELE: while (defined (my $allele = $allele_rs->next())) {
    my $allele_primary_identifier = $allele->primary_identifier();
    my $gene_primary_identifier = $allele->gene()->primary_identifier();

    my $allele_name = $allele->name();
    if (defined $allele_name) {
      $allele_name =~ s/\s+$//;
      $allele_name =~ s/^\s+//;
    }
    my $printable_allele_name = $allele_name // '*NO_NAME*';

    my $allele_type = $allele->type();

    my $allele_description = $allele->description();
    if (defined $allele_description) {
      $allele_description =~ s/\s+$//;
      $allele_description =~ s/^\s+//;
    }
    my $printable_allele_description = $allele_description // '*NO_DESCRIPTION*';

    my $allele_export_type = $allele_config->{$allele_type}->{export_type};

    if (!defined $allele_export_type) {
      if ($allele_type eq 'nonsense mutation') {
        $allele_export_type = 'nonsense_mutation';
      } else {
        if (defined $config->{export_type_to_allele_type}->{$allele_type}) {
          $allele_export_type = $allele_type;
        } else {
          warn "$curs_key: type not found: $allele_primary_identifier ",
            ($allele->{name} // '*NO_NAME*'), " $allele_type $printable_allele_description\n" ;
          next ALLELE;
        }
      }
    }

    my @chado_alleles = $allele_lookup->lookup_by_canto_systematic_id($allele_primary_identifier);

    if (@chado_alleles > 1) {
      die "$curs_key: too many Chado alleles for: $allele_primary_identifier\n";
    }

    if (@chado_alleles == 0) {
      if ($status eq 'APPROVED') {
        warn "$curs_key: no Chado alleles for $allele_primary_identifier\n";
      }
      next ALLELE;
    }

    my $chado_allele = $chado_alleles[0];
    my $chado_allele_name = $chado_allele->{name};
    my $chado_allele_type = $chado_allele->{type};
    my $chado_allele_canto_type = $config->{export_type_to_allele_type}->{$chado_allele_type};
    my $chado_allele_canto_type_name;

    if (defined $chado_allele_canto_type) {
      $chado_allele_canto_type_name = $chado_allele_canto_type->[0]->{name};
    } else {
      die "can't find Canto allele type for: $chado_allele_type\n";
    }

    my $chado_allele_description = $chado_allele->{description};
    my $chado_allele_systematic_id = $chado_allele->{allele_systematic_id};

    my $_deletion_name_match = sub {
      if ($allele_name eq $chado_allele_name) {
        return 1;
      }

      my $chado_gene = $_gene_from_chado->($gene_primary_identifier);

      if (defined $chado_gene) {
        my $gene_name = $chado_gene->{primary_name};

        if (defined $gene_name &&
            $allele_name =~ s/^$gene_primary_identifier/$gene_name/r eq
            $chado_allele_name =~ s/^$gene_primary_identifier/$gene_name/r) {
          return 1;
        }

        my $replacement = $gene_name // $gene_primary_identifier;
        for my $syn (@{$chado_gene->{synonyms}}) {
          if ($allele_name =~ s/^$syn/$replacement/r eq $chado_allele_name) {
            return 1;
          }
        }
      } else {
        return 0;
      }
    };

    my $set_type = 0;

    if ($allele_type eq 'unknown' && $chado_allele_canto_type_name ne 'unknown') {
      warn "$curs_key: setting type for ",
        qq|"$allele_name" from "unknown" to "$chado_allele_canto_type_name" (was $allele_type) $allele_primary_identifier / $chado_allele_systematic_id\n|;
      $set_type = 1;
      $allele->type($chado_allele_canto_type_name);
      $allele->update();
    }

    if (1) {
    if (defined $allele_name && $allele_name ne 'noname' &&
        $chado_allele_name ne $allele_name =~ s/[Δ∆]/delta/gr &&
        ($allele_type ne 'deletion' || !$_deletion_name_match->())) {
      warn "$curs_key: allele name in Chado differs from Canto, ",
        qq|"$chado_allele_name" vs "$allele_name" (for $allele_type $allele_primary_identifier / $chado_allele_systematic_id)\n|;
    }
    }

    if (defined $allele_description && $allele_description ne 'unknown') {
      if (0) {
      if (defined $chado_allele_description) {
        if ($chado_allele_description =~ s/, +/,/gr ne $allele_description =~ s/, +/,/gr) {
          warn "$curs_key: allele description for $printable_allele_name in Chado differs from Canto, ",
            qq|"$chado_allele_description" vs "$allele_description" (for $allele_primary_identifier / $chado_allele_systematic_id)\n|;
        }
      } else {
        if ($allele_type ne 'deletion' || $allele_description ne 'deletion') {
          warn "$curs_key: no description in Chado for $printable_allele_name($allele_description) $allele_primary_identifier\n";
        }
      }
      }
    } else {
      if (defined $chado_allele_description &&
          $chado_allele_description ne 'unknown' &&
          $allele_type ne 'deletion' &&
          $allele_type ne 'disruption' &&
          $allele_type !~ /^wild[_ ]type$/) {
        warn "$curs_key: setting description for ",
          qq|"$allele_name" to "$chado_allele_description" for $chado_allele_canto_type_name |,
          ($set_type ? '(was ' . $allele_type . ') ' : ''),
          qq|$allele_primary_identifier / $chado_allele_systematic_id  $chado_allele_type)\n|;

        $allele->description($chado_allele_description);
        $allele->update();
      }
    }

    if (0) {
    if (defined $chado_allele_description) {
      if (defined $allele_description && $allele_description ne 'unknown') {
        if ($chado_allele_description ne $allele_description) {
          warn qq|$curs_key: setting description of $allele_primary_identifier / $chado_allele_systematic_id $allele_type to |,
            qq|"$chado_allele_description" (was "$printable_allele_description")\n|;
        }
      } else {
#        warn qq|$curs_key: setting description of $allele_primary_identifier / $chado_allele_systematic_id $allele_type to |,
#          qq|"$chado_allele_description" (was unset)\n|;
      }
    } else {
      if (defined $allele_description && $allele_description ne 'unknown') {
        die $allele_description;
      }
    }

    if (defined $allele_name && $allele_name ne 'noname') {
      if ($chado_allele_name ne $allele_name) {
        warn qq|$curs_key: setting name of $allele_primary_identifier / $chado_allele_systematic_id $chado_allele_type|,
          " to ",
          qq|"$chado_allele_name" (was "$printable_allele_name")\n|;
      }
    } else {
#      warn qq|$curs_key: setting name of $allele_primary_identifier / $chado_allele_systematic_id $allele_type to |,
#        qq|"$chado_allele_name" (was unset)\n|;
    }
    #my $chado_external_uniquename = $chado_allele->{external_uniquename};
    }
  }
};

my $proc = sub {
  Canto::Track::curs_map($config, $track_schema, $add_proc);
};

$track_schema->txn_do($proc);


