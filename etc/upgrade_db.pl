#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Basename;
use Clone qw(clone);
use feature qw(switch);
no if $] >= 5.018, warnings => "experimental::smartmatch";

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use Canto::Config;
use Canto::Meta::Util;
use Canto::Track;
use Canto::TrackDB;
use Canto::CursDB;
use Canto::DBUtil;
use Canto::Curs::Utils;
use Canto::Curs::GenotypeManager;

if (@ARGV != 1) {
  die "$0: needs one argument - the version to upgrade to\n";
}

my $new_version = shift;

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}


my $config = Canto::Config::get_config();
my $track_schema = Canto::TrackDB->new(config => $config,
                                        disable_foreign_keys => 0);

my $current_version = Canto::DBUtil::get_schema_version($track_schema);

if ($current_version + 1 != $new_version) {
  warn "can only upgrade from version ", ($new_version - 1), " schema to $new_version, " .
    "database is currently version $current_version\n" .
    "exiting ...\n";
  exit (1);
}

my $dbh = $track_schema->storage()->dbh();

given ($new_version) {
  when (3) {
    $dbh->do("
ALTER TABLE person ADD COLUMN known_as TEXT;
");
  }
  when (4) {
    $dbh->do("
UPDATE cvterm SET name = replace(name, 'PomCur', 'Canto');
");
    $dbh->do("
UPDATE cv SET name = replace(name, 'PomCur', 'Canto');
");
  }
  when (5) {
    for my $sql ("PRAGMA foreign_keys = ON;",
                 "ALTER TABLE pub ADD COLUMN community_curatable BOOLEAN DEFAULT false;",
                 "UPDATE pub SET community_curatable = (SELECT pp.value = 'yes' FROM pubprop pp WHERE pub.pub_id = pp.pub_id AND pp.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'community_curatable'));",
                 "DELETE FROM pubprop WHERE type_id IN (SELECT cvterm_id FROM cvterm WHERE name = 'community_curatable');",
                 "DELETE FROM cvterm WHERE name = 'community_curatable';") {
      $dbh->do($sql);
    }
  }
  when (6) {
    use Digest::SHA qw(sha1_base64);

    my $proc = sub {
      my $person_rs = $track_schema->resultset('Person');

      while (defined (my $person = $person_rs->next())) {
        my $current_password = $person->password();
        if (defined $current_password) {
          $person->password(sha1_base64($current_password));
          $person->update();
        }
      }
    };

    $track_schema->txn_do($proc);
  }
  when (7) {
    $dbh->do("CREATE UNIQUE INDEX dbxref_db_accession_unique ON dbxref(accession, db_id);");
    $dbh->do("CREATE UNIQUE INDEX cvterm_name_cv_unique ON cvterm(name, cv_id);");
  }
  when (8) {
    my $update_proc = sub {
      my $curs = shift;
      my $curs_key = $curs->curs_key();
      my $curs_schema = shift;

      my $guard = $curs_schema->txn_scope_guard();

      my $rs = $curs_schema->resultset('Annotation')
        ->search({ type => { -like => '%interaction' } });

      for my $an ($rs->all()) {
        my $data = $an->data();

        my $interacting_genes = $data->{interacting_genes};

        if ($interacting_genes && @$interacting_genes > 1) {
          warn "splitting interaction annotation ID ", $an->annotation_id(),
            " in session $curs_key\n";

          for my $interacting_gene (@$interacting_genes) {
            my $new_data = clone $data;

            delete $new_data->{interacting_genes};

            $new_data->{interacting_genes} = [
              $interacting_gene,
            ];

            my $date_string = Canto::Curs::Utils::get_iso_date();

            my $new_annotation =
              $curs_schema->create_with_type('Annotation',
                                             {
                                               status => $an->status(),
                                               pub => $an->pub(),
                                               type => $an->type(),
                                               creation_date => $an->creation_date(),
                                               data => $new_data,
                                             });

            $curs_schema->create_with_type('GeneAnnotation',
                                           {
                                             gene => ($an->genes())[0],
                                             annotation => $new_annotation,
                                           });
          }

          $an->delete();
        }
      }

      $guard->commit();
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  }
  when (9) {
    my $strain_name = $config->{curs_config}->{genotype_config}->{default_strain_name};

    # upgrade to multi-allele genotypes
    my $update_proc = sub {
      my $curs = shift;
      my $curs_key = $curs->curs_key();
      my $curs_schema = shift;

      my %seen_alleles = ();

      warn "upgrading: $curs_key\n";

      my $guard = $curs_schema->txn_scope_guard();

      my $genotype_manager = Canto::Curs::GenotypeManager->new(config => $config,
                                                               curs_schema => $curs_schema);

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("ALTER TABLE allele ADD COLUMN expression TEXT;");

      $curs_dbh->do("
CREATE TABLE genotype_annotation (
       genotype_annotation_id integer PRIMARY KEY,
       genotype integer REFERENCES genotype(genotype_id),
       annotation integer REFERENCES annotation(annotation_id)
);
");

      $curs_dbh->do("
CREATE TABLE genotype (
       genotype_id integer PRIMARY KEY AUTOINCREMENT,
       identifier text UNIQUE NOT NULL,
       name text UNIQUE
);
");

      $curs_dbh->do("
CREATE TABLE allele_genotype (
       allele_genotype_id integer PRIMARY KEY,
       allele integer REFERENCES allele(allele_id),
       genotype integer REFERENCES genotype(genotype_id)
);
");

      my $allele_rs = $curs_schema->resultset('Allele');

      while (defined (my $allele = $allele_rs->next())) {
        my $display_name = $allele->display_name();

        if ($seen_alleles{$display_name}) {
          warn "WARNING - skipping: $display_name\n";
          next;
        }

        $seen_alleles{$display_name} = 1;

        my $genotype_name = "$strain_name " . $display_name;

        warn "  genotype name: $genotype_name  allele_id: ", $allele->allele_id(), "\n";
        my $genotype = $genotype_manager->make_genotype($curs_key, $genotype_name,
                                                        [$allele]);

        my $sth = $curs_dbh->prepare("select annotation from allele_annotation where allele = ? " .
                                       "and annotation in (select annotation_id from annotation)");

        $sth->execute($allele->allele_id());

        while (my ($annotation_id) = $sth->fetchrow_array()) {
          my $annotation = $curs_schema->resultset('Annotation')->find($annotation_id);

          my $data = $annotation->data();
          my $expression = delete $data->{expression};

          if ($expression) {
            warn "    moved '$expression'\n";
            $allele->expression($expression);
          }

          $annotation->data($data);
          $annotation->update();

          my $insert_sth =
            $curs_dbh->prepare("insert into genotype_annotation(genotype, annotation) " .
                               "values (?, ?)");
          $insert_sth->execute($genotype->genotype_id(), $annotation_id);
        }
      }

      my $an_rs = $curs_schema->resultset('Annotation');

      for my $an ($an_rs->all()) {
        my $data = $an->data();
      }

      $curs_dbh->do("drop table allele_annotation");

      $guard->commit();
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  }
  default {
    die "don't know how to upgrade to version $new_version";
  }
}

Canto::DBUtil::set_schema_version($track_schema, $new_version);
