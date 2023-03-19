#!/usr/bin/env perl

# find term alt_ids used in annotations and in annotation extensions
# and change to use the primary ID
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


my $db_name = shift;

if (!defined $db_name) {
  die "needs one arg, eg.
  $0 'GO'
";
}


my %alt_id_to_id_map = ();

my $track_dbh = $track_schema->storage()->dbh();

my %term_names_map = ();

my $term_names_sth =
  $track_dbh->prepare("
SELECT db.name || ':' || x.accession AS term_id,
       t.name AS term_name
  FROM cvterm t JOIN dbxref x ON x.dbxref_id = t.dbxref_id
  JOIN db ON db.db_id = x.db_id
  WHERE db.name = ?");

$term_names_sth->execute($db_name);

while (my ($term_id, $term_name) = $term_names_sth->fetchrow_array()) {
  $term_names_map{$term_id} = $term_name;
}


my $alt_ids_sth =
  $track_dbh->prepare("
SELECT db.name || ':' || x.accession AS term_id,
       db.name || ':' || alt_x.accession AS alt_id
  FROM cvterm t JOIN dbxref x ON x.dbxref_id = t.dbxref_id
  JOIN db ON db.db_id = x.db_id
  JOIN cvterm_dbxref tx ON tx.cvterm_id = t.cvterm_id
  JOIN dbxref alt_x ON alt_x.dbxref_id = tx.dbxref_id
 WHERE x.db_id = alt_x.db_id AND db.name = ?;");

$alt_ids_sth->execute($db_name);

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
              my $range_term_id = $and_part->{rangeValue};

              if (exists $alt_id_to_id_map{$range_term_id}) {
                $changed = 1;
                my $primary_id = $alt_id_to_id_map{$range_term_id};
                my $primary_name = $term_names_map{$primary_id} or die;

                warn "$curs_key: found alt_id in extension: $range_term_id -> $primary_id ($primary_name)\n";
                $and_part->{rangeValue} = $primary_id;
                $and_part->{rangeDisplayName} = $primary_name;
                $and_part->{rangeType} = 'Ontology';
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

