#!/usr/bin/env perl

# Export annotation comments in the format:
#   COMMENT: 0572af570458b258 36 ny0fl4sRbLpnBiU3wPWyKdIC7Dc
#   Fig. 2BC
#   -------
#   COMMENT: 0572af570458b258 37 BPIrlYzNtwX2QPFlJb7spS+aWDY
#   The resulting cwh43 pdt1Δ
#   201 double mutant partly recovered colony formation capacity at 36°C, compared to that of the
#   202 cwh43 single mutant (Fig. 2D).
#   -------
#   ...
#
# See also: import_comments.pl

use strict;
use warnings;
use Carp;

use Digest::SHA qw(sha1_base64);
use Encode;

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



my $proc = sub {
  my $curs = shift;
  my $cursdb = shift;
  my $curs_key = $curs->curs_key();

  my $annotation_rs = $cursdb->resultset('Annotation');

  while (defined (my $annotation = $annotation_rs->next())) {
    my $data = $annotation->data();

    if ($data->{submitter_comment}) {
      my $comm = $data->{submitter_comment};

      my $checksum = sha1_base64(Encode::encode_utf8($comm));

      print "COMMENT: $curs_key ", $annotation->annotation_id(), " $checksum\n$comm\n";
      print "-------\n";
    }
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);

