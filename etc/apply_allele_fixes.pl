#!/usr/bin/env perl

# Use the output of Manu's code to find and fix allele descriptions
# and types
#
# See: https://github.com/pombase/canto/issues/2689
#
# Run in the canto directory like:
#   ./etc/apply_allele_fixes.pl <PATH_TO_ALLELE_FIX_TSV_FILE>

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


my %allele_export_type_map = ();

while (my ($export_type, $details) = each %{$config->{export_type_to_allele_type}}) {
  $allele_export_type_map{$export_type} = $details->[0]->{name};
}



my $change_file = shift;

if (!defined $change_file) {
  die "needs one arg - the file of allele fixes\n";
}

open my $change_fh, '<', $change_file or die;



my $tsv = Text::CSV->new({ sep_char => "\t", binary => 1,
                           auto_diag => 1, strict => 1 });

$tsv->column_names($tsv->getline($change_fh));

# $VAR1 = [
#           {
#             'change_description_to' => '196-245',
#             'systematic_id' => 'SPAC1006.03c',
#             'change_type_to' => '',
#             'allele_name' => 'red1-delta196-245',
#             'rules_applied' => 'partial_amino_acid_deletion:multiple_aa',
#             'sequence_error' => '',
#             'reference' => 'PMID:32012158',
#             'allele_type' => 'partial_amino_acid_deletion',
#             'solution_index' => '',
#             'allele_parts' => '196 -245',
#             'allele_description' => '196 -245',
#             'auto_fix_comment' => 'syntax_error'
#           }
#         ];

my %change_map = ();

while (my $row = $tsv->getline_hr($change_fh)) {
  if (defined $row->{solution_index} && $row->{solution_index} ne '') {
    next;
  }

  if (exists $change_map{$row->{allele_name}}) {
    warn "ignoring duplicate allele_name: ", $row->{allele_name}, "\n";
    next;
  }

  $change_map{$row->{allele_name}} = $row;
}


my $proc = sub {
  my $curs = shift;
  my $cursdb = shift;
  my $curs_key = $curs->curs_key();

  my $allele_rs = $cursdb->resultset('Allele');

  while (defined (my $allele = $allele_rs->next())) {
    my $name = $allele->name();
    if ($name) {
      my $changes = $change_map{$name};

      if (defined $changes) {
        my $new_description = $changes->{change_description_to};

        if ($new_description) {
          my $old_description = $allele->description() // '';
          $old_description =~ s/,\s+/,/g;

          if ($old_description ne $changes->{allele_description} &&
            $old_description ne '' && lc $old_description ne 'unknown') {
            warn qq|for "$name" description in DB doesn't match file: "$old_description" vs "|,
              $changes->{allele_description}, qq|"\n|;
          } else {
            print qq|$curs_key: $name: changing description "$old_description" to "$new_description"\n|;
            $allele->description($new_description);
            $allele->update();
          }
        }

        my $new_type = $changes->{change_type_to};

        if ($new_type) {
          $new_type = 'other' if $new_type eq 'amino_acid_other';
          my $new_type_name = $allele_export_type_map{$new_type};
          if (!defined $new_type_name) {
            warn "Unknown allele type: $new_type\n";
            next;
          }

          my $old_type = $allele->type();
          print qq|$curs_key: $name: changing type "$old_type" to "$new_type_name"\n|;
          $allele->type($new_type);
          $allele->update();
        }

        my $new_name = $changes->{change_name_to};

        if ($new_name) {
          my $old_name = $allele->name();
          print qq|$curs_key: $name: changing name to "$new_name"\n|;
          $allele->name($new_name);
          if ($old_name) {
            $cursdb->resultset('Allelesynonym')
              ->create({ allele => $allele->allele_id(),
                         edit_status => 'new',
                         synonym => $old_name });
          }

          $allele->update();
        }
      }
    }
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);

