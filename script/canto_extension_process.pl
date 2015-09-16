#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use feature ':5.10';

use File::Temp qw/ tempfile /;
use File::Basename;
use List::MoreUtils qw(uniq);

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
use Canto::Meta::Util;

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

sub usage
{
  my $message = shift;

  if ($message) {
    warn "$message\n";
  }

  die "usage:
  $0 extension_conf_file <OBO file names>
";
}

if (!@ARGV || $ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
  usage();
}

my (@filenames) = @ARGV;

if (!@filenames) {
  usage "missing OBO file name argument(s)";
}

my $config = Canto::Config::get_config();
my $schema = Canto::TrackDB->new(config => $config);

my $ext_conf = $config->{extension_configuration};

if (!$ext_conf) {
  die "no extension configuration file set - exiting\n";
}

my @conf = @{$ext_conf};

my %subsets = ();

for my $filename (@filenames) {
  my ($temp_fh, $temp_filename) = tempfile();

  system ("owltools $filename --save-closure-for-chado $temp_filename") == 0
    or die "can't open pipe from owltools: $?";

  open my $owltools_out, '<', $temp_filename
    or die "can't open owltools output from $temp_filename: $!\n";

  while (defined (my $line = <$owltools_out>)) {
    chomp $line;
    my ($subject, $rel_type, $depth, $object) =
      split (/\t/, $line);

    die $line unless $rel_type;

    $rel_type =~ s/^OBO_REL://;

    for my $conf (@conf) {
      if ($conf->{domain} eq $object && $conf->{subset_rel} eq $rel_type) {
        $subsets{$subject}{$object} = 1;
      }
    }
  }
}

my @domains = uniq map { $_->{domain}; } @conf;

my %db_names = ();

map {
  if (/(\w+):/) {
    $db_names{$1} = 1;
  }
} keys %subsets;

my @db_names = keys %db_names;

my $cvterm_rs =
  $schema->resultset('Cvterm')->search({
    'db.name' => { -in => \@db_names },
  }, {
    join => { dbxref => 'db' },
    prefetch => { dbxref => 'db' }
  });

my $canto_subset_term =
  $schema->resultset('Cvterm')->find({ name => 'canto_subset',
                                       'cv.name' => 'cvterm_property_type' },
                                     { join => 'cv' });

while (defined (my $cvterm = $cvterm_rs->next())) {
  my $db_accession = $cvterm->db_accession();

  my $prop_rs =
    $cvterm->cvtermprop_cvterms()
    ->search({
      type_id => $canto_subset_term->cvterm_id(),
    });

  my $guard = $schema->txn_scope_guard();

  $prop_rs->delete();

  my $subset_ids = $subsets{$db_accession};

  if ($subset_ids) {
    my @subset_ids = keys %{$subset_ids};

    for (my $rank = 0; $rank < @subset_ids; $rank++) {
      my $subset_id = $subset_ids[$rank];
      $schema->resultset('Cvtermprop')->create({
        cvterm_id => $cvterm->cvterm_id(),
        type_id => $canto_subset_term->cvterm_id(),
        value => $subset_id,
        rank => $rank,
      });
    }
  }

  $guard->commit();
}
