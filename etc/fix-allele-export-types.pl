#!/usr/bin/env perl

# fix allele that (accidentally) have the export allele type instead of the
# Canto allele type

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



my %allele_export_type_map = ();

while (my ($export_type, $details) = each %{$config->{export_type_to_allele_type}}) {
  $allele_export_type_map{$export_type} = $details->[0]->{name};
}


my $proc = sub {
  my $curs = shift;
  my $cursdb = shift;
  my $curs_key = $curs->curs_key();

  my $allele_rs = $cursdb->resultset('Allele');

  while (defined (my $allele = $allele_rs->next())) {
    my $allele_type = $allele->type();

    my $canto_type = $allele_export_type_map{$allele_type};

    if (defined $canto_type) {
      $allele->type($canto_type);
      $allele->update();
    }
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);

