#!/usr/bin/env perl

# Use the output of Manu's code to find and fix modifications in Canto
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


my $change_file = shift;

if (!defined $change_file) {
  die "needs one arg - the file of allele fixes\n";
}

open my $change_fh, '<', $change_file or die;


my $tsv = Text::CSV->new({ sep_char => "\t", binary => 1,
                           quote_char => undef,
                           auto_diag => 1 });

$tsv->column_names($tsv->getline($change_fh));

my %change_map = ();

while (my $row = $tsv->getline_hr($change_fh)) {
  my $systematic_id = $row->{systematic_id};
  my $modification = $row->{modification};
  my $sequence_position = $row->{sequence_position};
  my $evidence = $row->{evidence};
  my $date = $row->{date};
  my $reference = $row->{reference};

  my $solution_index = $row->{solution_index};

  if (defined $solution_index && $solution_index =~ /\d+/) {
    next;
  }

  my $key = "$systematic_id--$modification--$sequence_position--$evidence--$reference";

  my $change_sequence_position_to = $row->{change_sequence_position_to};

  my $pos = $change_map{$key};

  if (defined $pos && $change_sequence_position_to ne $pos) {
    die "$pos $key\n";
  }

  $change_map{$key} = $change_sequence_position_to;
}

my $proc = sub {
  my $curs = shift;
  my $cursdb = shift;
  my $curs_key = $curs->curs_key();

  my $pub_uniquename = $curs->pub()->uniquename();

  my $gene_annotation_rs = $cursdb->resultset('GeneAnnotation');

  while (defined (my $gene_annotation = $gene_annotation_rs->next())) {
    my $systematic_id = $gene_annotation->gene()->primary_identifier();
    my $annotation = $gene_annotation->annotation();
    my $data = $annotation->data();

    my $term_ontid = $data->{term_ontid};

    if (!$term_ontid || $term_ontid !~ /^MOD:/) {
      next;
    }

    my $modification = $term_ontid;
    my $reference = $pub_uniquename;
    my $date = $annotation->creation_date();

    my $evidence = $config->{evidence_types}->{$data->{evidence_code}}->{name};


    if (!$data->{extension}) {
      next;
    }

    my $do_update = 0;

    for my $extension_or_part (@{$data->{extension}}) {

      for my $extension_and_part (@{$extension_or_part}) {

        if ($extension_and_part->{relation} &&
            $extension_and_part->{relation} eq 'residue') {
          my $sequence_position = $extension_and_part->{rangeValue};

          if (!defined $date) {
            use Data::Dumper;
            die 'no date: ', Dumper([$curs_key, $systematic_id, $modification, $sequence_position, $data]);
          }

          my $key = "$systematic_id--$modification--$sequence_position--$evidence--$reference";

          my $change_sequence_position_to = $change_map{$key};

          if (!defined $change_sequence_position_to) {
            next;
          }

          print "$curs_key: changing $systematic_id $reference $term_ontid $sequence_position to $change_sequence_position_to\n";

          $extension_and_part->{rangeValue} = $change_sequence_position_to;
          $extension_and_part->{rangeDisplayName} = $change_sequence_position_to;

          $do_update = 1;
        }
      }
    }

    if ($do_update) {
      $annotation->data($data);
      $annotation->update();
    }
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);

