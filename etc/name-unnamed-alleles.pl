#!/usr/bin/env perl

# Attempt to name unnamed alleles using the gene name and allele descriptions
#
# See: https://github.com/pombase/allele_qc/issues/66
#
# Run in the canto directory like:
#   ./etc/apply_modification_fixes.pl <PATH_TO_MOD_FIX_TSV_FILE>

use strict;
use warnings;
use Carp;

use Text::CSV;

use File::Basename;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    chdir "..";
  }
};

use open ':std', ':encoding(UTF-8)';

use lib qw(lib);

use Canto::Config;
use Canto::TrackDB;
use Canto::ChadoDB;
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
my $chado_schema = Canto::ChadoDB->new(config => $config);


my %chado_gene_names = ();

my $chado_dbh = $chado_schema->storage()->dbh();

my $gene_names_sth =
  $chado_dbh->prepare("
SELECT uniquename, name
FROM feature
WHERE type_id IN (SELECT cvterm_id FROM cvterm WHERE name = 'gene')
    AND uniquename IS NOT NULL;");

$gene_names_sth->execute();

while (my ($uniquename, $name) = $gene_names_sth->fetchrow_array()) {
  $chado_gene_names{$uniquename} = $name
}


sub description_ok {
  my $gene_name = shift;
  my $allele_type = shift;
  my $allele_description = shift;

  map {
    if ($allele_type eq 'nucleotide substitution(s)' &&
        !/^[ATGCU]+-?(\d+|\(-\d+\))-?[ATGCU]+$/) {
      return 0;
    }
    if ($allele_type eq 'amino acid substitution(s)' &&
        !/^[ARNDCQEGHILKMFPOSUTWYVBZXJ]+-?(\d+|\(-\d+\))-?[ARNDCQEGHILKMFPOSUTWYVBZXJ]+$/) {
      return 0;
    }
    if ($allele_type eq 'partial deletion, amino acid' &&
        !/^\d+$|^\d+-\d+$|^[ARNDCQEGHILKMFPOSUTWYVBZXJ]\d+\*$/) {
      return 0;
    }
  } split /,/, $allele_description;

  return 1;
}

my $count = 0;

my @types_to_process = (
  'amino acid substitution(s)',
  'nucleotide substitution(s)',
  'partial deletion, amino acid');

my $proc = sub {
  my $curs = shift;
  my $cursdb = shift;
  my $curs_key = $curs->curs_key();

  my $allele_rs = $cursdb->resultset('Allele');

  while (defined (my $allele = $allele_rs->next())) {
    my $gene = $allele->gene();
    my $gene_uniquename = $gene->primary_identifier();
    my $allele_name = $allele->name();

    my $allele_type = $allele->type();

    if (!grep { $_ eq $allele_type } @types_to_process) {
      next;
    }

    my $allele_description = $allele->description();

    my $gene_name = $chado_gene_names{$gene_uniquename} // $gene_uniquename;

    my $old_allele_name = $allele_name // 'NO_NAME';

    if (!defined $allele_description) {
      warn "no description $curs_key $allele_name: $allele_name $allele_type\n";
      next;
    }

    if (!description_ok($gene_name, $allele_type, $allele_description)) {
      if (!defined $allele_name || $allele_name !~ /^$gene_name-/) {
        warn "skipping $curs_key $old_allele_name: $gene_name   type: $allele_type   desc: $allele_description\n";
      }
      next;
    }

    my $connector = '-';

    if ($allele_type eq 'partial deletion, amino acid') {
      $connector = 'delta';
    }

    if (defined $allele_name) {
      if ($allele_name ne $allele_description ||
          $allele_description =~ /^$gene_name-/) {
        next;
      } else {
        $allele_name = "$gene_name$connector$allele_name";
      }
    } else {
      $allele_name = "$gene_name$connector$allele_description";
    }

    $count++;
    print "setting name from $old_allele_name to $allele_name\n";

    $allele->name($allele_name);
    $allele->update();
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);


warn "set $count allele names\n";
