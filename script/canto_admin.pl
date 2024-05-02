#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use feature ':5.10';

use Try::Tiny;

use File::Basename;
use Getopt::Long;
use Encode qw(decode);

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
use Canto::Track::TrackUtil;
use Canto::Meta::Util;


if (!@ARGV) {
  usage();
}

my $refresh_gene_cache = undef;
my $rename_strain = undef;
my $merge_strains = undef;
my $change_taxonid = undef;
my $delete_unused_strains = undef;
my $update_annotation_curators = undef;
my $change_gene_id = undef;
my $no_rename = 0;

my $dry_run = 0;
my $do_help = 0;

my $result = GetOptions ("refresh-gene-cache" => \$refresh_gene_cache,
                         "rename-strain" => \$rename_strain,
                         "merge-strains" => \$merge_strains,
                         "change-taxonid" => \$change_taxonid,
                         "delete-unused-strains" => \$delete_unused_strains,
                         "update-annotation-curators" => \$update_annotation_curators,
                         "change-gene-id" => \$change_gene_id,
                         "dry-run|d" => \$dry_run,
                         "help|h" => \$do_help,
                         "no-rename" => \$no_rename);

sub usage
{
  my $message = shift;

  if (defined $message) {
    $message .= "\n";
  } else {
    $message = '';
  }

  die qq|${message}usage:
  $0 --refresh-gene-cache
  This option will update all the name and synonyms for all genes cached by
  UniProt::GeneLookup.

  $0 --rename-strain taxonid old_name new_name
  Rename a strain in <taxonid> from <old_name> to <new_name>

  $0 --merge-strains taxonid old_name new_name
  Merge strain <old_name> in <taxonid> into <new_name>, <old_name> will be
  removed and all sessions using <old_name> will be changed to use <new_name>

  $0 --change-taxonid old_taxonid new_taxonid
  Change <old_taxonid> to <new_taxonid> everywhere, including in the sessions

  $0 --delete-unused-strains
  Remove all strains that are not used in any session

  $0 --update-annotation-curators
  Set the curator_orcid field of the annotations if available in the
  person table

  $0 --change-gene-id [--no-rename] <from_id> <to_id>
  Change <from_id> to <to_id> for all genes and alleles in every session.
  If --no-rename is set, skip renaming alleles.
|;
}

if ($do_help) {
  usage();
}

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

if ($rename_strain && @ARGV != 3) {
  warn "Error: --rename-strain needs three arguments\n\n";
  usage();
}

if ($merge_strains && @ARGV != 3) {
  warn "Error: --merge-strains needs three arguments\n\n";
  usage();
}

if ($change_taxonid && @ARGV != 2) {
  warn "Error: --change-taxonid needs two arguments\n\n";
  usage();
}

if ($delete_unused_strains && @ARGV > 0) {
  warn "Error: too many arguments for --delete-unused-strains\n\n";
  usage();
}

if ($update_annotation_curators && @ARGV > 0) {
  warn "Error: too many arguments for --update-annotation-curators\n\n";
  usage();
}

if ($change_gene_id && @ARGV != 2) {
  warn "Error: --change-gene-id needs two arguments\n\n";
  usage();
}

if ($no_rename && !defined $change_gene_id) {
  warn "Error: --no-rename is only allowed with --change-gene-id\n\n";
  usage();
}

my $config = Canto::Config::get_config();
my $schema = Canto::TrackDB->new(config => $config);

my $exit_flag = 1;

my $util = Canto::Track::TrackUtil->new(config => $config, schema => $schema);

my $proc = sub {
  if (defined $rename_strain) {
    my $taxonid = shift @ARGV;
    my $old_name = decode("utf-8", shift @ARGV);
    my $new_name = decode("utf-8", shift @ARGV);

    try {
      $util->rename_strain($taxonid, $old_name, $new_name);
      $exit_flag = 0;
    } catch {
      warn "rename failed: $_\n";
    };
  }

  if (defined $merge_strains) {
    my $taxonid = shift @ARGV;
    my $old_name = decode("utf-8", shift @ARGV);
    my $new_name = decode("utf-8", shift @ARGV);

    try {
      $util->merge_strains($taxonid, $old_name, $new_name);
      $exit_flag = 0;
    } catch {
      warn "merge failed: $_\n";
    };
  }

  if (defined $change_taxonid) {
    my $old_taxonid = shift @ARGV;
    my $new_taxonid = shift @ARGV;

    try {
      $util->change_taxonid($old_taxonid, $new_taxonid);
      $exit_flag = 0;
    } catch {
      warn "changing taxon ID failed: $_\n";
    };
  }

  if (defined $delete_unused_strains) {
    try {
      my $count = $util->delete_unused_strains();
      $exit_flag = 0;
      print "$0: deleted $count strains from the TrackDB\n";
    } catch {
      warn "failed to delete unused strains: $_\n";
    };
  }

  if (defined $update_annotation_curators) {
    try {
      $util->update_annotation_curators();
      $exit_flag = 0;
    } catch {
      warn "failing to update annotation curator field: $_\n";
    };
  }

  if (defined $change_gene_id) {
    my $from_id = shift @ARGV;
    my $to_id = shift @ARGV;

    $util->change_gene_id($from_id, $to_id, $no_rename);

    $exit_flag = 0;
  }
};

if (defined $refresh_gene_cache) {
  # don't run in a single transaction because it's slow
  Canto::Track::refresh_gene_cache($config, $schema);
  $exit_flag = 0;
} else {
  $schema->txn_do($proc);
}

exit $exit_flag;
