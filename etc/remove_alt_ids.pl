#!/usr/bin/env perl

# find term alt_ids used in annotation and change to use the primary ID
#
# See: https://github.com/pombase/canto/issues/2708

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


my %alt_id_to_id_map = ();

my $track_dbh = $track_schema->storage()->dbh();

my $alt_ids_sth =
  $track_dbh->prepare("
SELECT db.name || ':' || x.accession AS term_id, db.name || ':' || alt_x.accession AS alt_id
  FROM cvterm t JOIN dbxref x ON x.dbxref_id = t.dbxref_id
  JOIN db ON db.db_id = x.db_id
  JOIN cvterm_dbxref tx ON tx.cvterm_id = t.cvterm_id
  JOIN dbxref alt_x ON alt_x.dbxref_id = tx.dbxref_id
 WHERE x.db_id = alt_x.db_id;");

$alt_ids_sth->execute();

while (my ($term_id, $alt_id) = $alt_ids_sth->fetchrow_array()) {
  if ($alt_id_to_id_map{$alt_id}) {
    die $alt_id;
  }
  $alt_id_to_id_map{$alt_id} = $term_id;
}

my $proc = sub {
  my $curs = shift;
  my $cursdb = shift;
  my $curs_key = $curs->curs_key();

  my $annotation_rs = $cursdb->resultset('Annotation');

  while (defined (my $annotation = $annotation_rs->next())) {

    my $data = $annotation->data();

    if ($data->{term_ontid}) {
      my $term_id = $data->{term_ontid};

      print "$term_id\n";

      if (exists $alt_id_to_id_map{$term_id}) {
        warn "$curs_key: found annotation using alt_id: $term_id\n";
      }
    }

    my $changed = 0;

    my $extension = $data->{extension};

    if (defined $extension) {

        map {
          my $or_part = $_;
          map {
            my $and_part = $_;

            if ($and_part->{rangeValue}) {
              my $range_value_term_id = $and_part->{rangeValue};

              if (exists $alt_id_to_id_map{$range_value_term_id}) {
                $changed = 1;
                warn "$curs_key: found alt_id in extension: $range_value_term_id\n";
              }
            }

          } @$or_part;
        } @$extension;
    }

    if ($changed) {
      $annotation->data($data);
      $annotation->update();
    }
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);

