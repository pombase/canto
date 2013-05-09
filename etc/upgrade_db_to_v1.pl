#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Basename;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use PomCur::Config;
use PomCur::Meta::Util;
use PomCur::TrackDB;
use PomCur::Track;
use PomCur::Track::CuratorManager;
use PomCur::Role::MetadataAccess;

my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}


my $config = PomCur::Config::get_config();
my $track_schema = PomCur::TrackDB->new(config => $config,
                                        disable_foreign_keys => 1);

my $schema_version_rs =
  $track_schema->resultset('Metadata')
               ->search({ 'type.name' => 'schema_version' },
                        { join => 'type' });
my $current_db_version = $schema_version_rs->first()->value();

if ($current_db_version == 0) {
  my $schema_version_row = $schema_version_rs->first();
  $schema_version_row->value(1);
  $schema_version_row->update();
} else {
  die "can't upgrade schema_version: $current_db_version\n";
}

my $dbh = $track_schema->storage()->dbh();
$dbh->do("
CREATE TABLE curs_curator (
       curs_curator_id integer NOT NULL PRIMARY KEY,
       curs integer REFERENCES curs(curs_id) NOT NULL,
       curator integer REFERENCES person(person_id) NOT NULL
);
");

$dbh->do("
CREATE TABLE pub_new (
       pub_id integer NOT NULL PRIMARY KEY,
       uniquename text UNIQUE NOT NULL,
       type_id integer NOT NULL REFERENCES cvterm (cvterm_id),
       corresponding_author integer REFERENCES person (person_id),
       title text,
       abstract text,
       authors text,
       affiliation text,
       citation text,
       publication_date text,
       pubmed_type integer REFERENCES cvterm (cvterm_id),
       triage_status_id integer NOT NULL REFERENCES cvterm (cvterm_id),
       load_type_id integer NOT NULL REFERENCES cvterm (cvterm_id),
       curation_priority_id integer REFERENCES cvterm (cvterm_id),
       added_date timestamp
);
");

$dbh->do("
INSERT INTO pub_new SELECT
  pub_id, uniquename, type_id, assigned_curator corresponding_author, title,
  abstract, authors, affiliation, citation, publication_date, pubmed_type,
  triage_status_id, load_type_id, curation_priority_id, added_date FROM pub;
");

$dbh->do("DROP TABLE pub;");

$dbh->do("ALTER TABLE pub_new RENAME TO pub;");

$dbh->do("CREATE INDEX pub_triage_status_idx ON pub(triage_status_id);");

my $iter = PomCur::Track::curs_iterator($config, $track_schema);

my $curator_manager =
  PomCur::Track::CuratorManager->new(config => $config);

while (my ($curs, $cursdb) = $iter->()) {
  warn "upgrading: ", $curs->curs_key(), "\n";
  my $submitter_email =
    PomCur::Role::MetadataAccess->get_metadata($cursdb, 'submitter_email');
  PomCur::Role::MetadataAccess->unset_metadata($cursdb, 'submitter_email');
  my $submitter_name =
    PomCur::Role::MetadataAccess->get_metadata($cursdb, 'submitter_name');
  PomCur::Role::MetadataAccess->unset_metadata($cursdb, 'submitter_name');

  if (!defined $submitter_email) {
    die if defined $submitter_name;

    warn "skipping - no email\n";
    next;
  }

  if (!defined $submitter_name) {
    die;
  }

  $curator_manager->set_curator($curs->curs_key(), $submitter_email,
                                $submitter_name);

  for my $annotation ($cursdb->resultset('Annotation')->all()) {
    my $data = $annotation->data();
    $data->{curator} = {
      name => $submitter_name,
      email => $submitter_email,
    };
    $annotation->data($data);
    $annotation->update();
  }
}

