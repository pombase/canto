#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Basename;
use Clone qw(clone);
use feature qw(switch);
use feature 'unicode_strings';
use charnames ':full';

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

sub is_aa_mutation_desc
{
  my $description = shift;

  return 0 unless defined $description;

  my $seen_aa_desc = 0;

  if ($description =~ /\s*,\s*/) {
    for my $bit (split /\s*,\s*/, $description) {
      if (_could_be_aa_mutation_desc($bit)) {
        if (!_is_na_mutation_desc($bit)) {
          $seen_aa_desc = 1;
        }
      } else {
        return 0;
      }
    }

    return $seen_aa_desc;
  }

  return _could_be_aa_mutation_desc($description) && !_is_na_mutation_desc($description);
}

sub _could_be_aa_mutation_desc
{
  my $description = shift;

  return $description =~ /^[a-z]+\d+[a-z]+$/i;
}

sub _is_na_mutation_desc
{
  my $description = shift;

  return $description =~ /^[atgc]+\d+[atgc]+$/i;
}

sub allele_type_from_desc
{
  my ($description, $gene_name) = @_;

  $description =~ s/^\s+//;
  $description =~ s/\s+$//;

  if (grep { $_ eq $description } ('deletion', 'wild_type', 'wild type', 'unknown', 'other', 'unrecorded')) {
    return ($description =~ s/\s+/_/r);
  } else {
    if (is_aa_mutation_desc($description)) {
      return 'amino_acid_mutation';
    } else {
      if ($description =~ /^[A-Z]\d+\s*->\s*(amber|ochre|opal|stop)$/i) {
        return 'nonsense_mutation';
      } else {
        if (defined $gene_name && $description =~ /^$gene_name/) {
          return 'other';
        }
      }
    }
  }

  return undef;
}

no if $] >= 5.018, warnings => "experimental::smartmatch";

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

my $comma_substitute = "<<COMMA>>";

sub _replace_commas
{
  my $string = shift;

  $string =~ s/,/$comma_substitute/g;
  return $string;
}

sub _unreplace_commas
{
  my $string = shift;

  $string =~ s/$comma_substitute/,/g;
  return $string;
}

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

      warn "upgrading: $curs_key\n";

      my $guard = $curs_schema->txn_scope_guard();

      my $curs_dbh = $curs_schema->storage()->dbh();

      my $gene_rs = $curs_schema->resultset('Gene');

    GENE: while (defined (my $gene = $gene_rs->next())) {
        for my $annotation ($gene->direct_annotations()) {
          my $data = $annotation->data();
          my $extension = $data->{annotation_extension};
          if ($extension && $extension =~ /allele=/) {
            # remove some crud
            $extension =~ s/[\s\N{ZERO WIDTH SPACE}]/ /g;
            $extension =~ s/
                             (
                               \N{ZERO WIDTH SPACE}
                             |
                               \N{LATIN SMALL LETTER A WITH CIRCUMFLEX}
                             |
                               \N{PADDING CHARACTER}
                               \N{PARTIAL LINE FORWARD}
                             |
                               \x{80}
                               \x{8B}
                             )
                             \s*/ /gx;


            chomp $extension;

            $extension =~ s/\|\s*$//;

            my @parts = split /\|/, $extension;

            for my $part (@parts) {
              my @rest = ();
              my $allele = undef;
              my $allele_type = undef;
              my @conditions = ();

              $part =~ s/(\([^\)]+\))/_replace_commas($1)/eg;

              chomp $part;
              $part =~ s/,\s*$//;

              my @bits = split /,/, $part;

              for my $bit (@bits) {
                $bit = _unreplace_commas($bit);

                $bit =~ s/^\s+//;
                $bit =~ s/\s+$//;

                if ($bit =~ /^\s*(\S+)=\s*(.+)\s*$/) {
                  if ($1 eq 'allele') {
                    if ($allele) {
                      die "'allele=' occurs twice in extension: $extension\n";
                    } else {
                      $allele = $2;
                    }
                  } else {
                    if ($1 eq 'allele_type') {
                      if ($allele_type) {
                        die "'allele_type=' occurs twice in extension: $extension\n";
                      } else {
                        $allele_type = $2;
                      }
                    } else {
                      if ($1 eq 'condition') {
                        push @conditions, $2
                      } else {
                        push @rest, $bit;
                      }
                    }
                  }
                } else {
                  if ($bit =~ /^\s*\S+\([^\)]+\)\s*$/) {
                    # an "relation(id)" without "extension="
                    push @rest, $bit;
                  } else {
                    warn "'$bit', skipping gene with non-parsable extension: $extension\n";
                    next GENE;
                  }
                }
              }

              if (@conditions && !$allele) {
                die "no allele= for $extension\n";
              }

              if (@conditions) {
                $data->{conditions} = [@conditions];
              }

              if (@rest) {
                $data->{annotation_extension} = join ',', @rest;
              } else {
                delete $data->{annotation_extension};
              }

              my $new_annotation =
                $curs_schema->resultset('Annotation')
                  ->create({ status => $annotation->status(),
                             pub => $annotation->pub(),
                             type => $annotation->type(),
                             creation_date => $annotation->creation_date(),
                             data => $data });

              if ($allele) {
                if ($allele =~ /^(\S+)delta$/) {
                  $allele = "$allele(deletion)";
                }
                if (my ($name, $description) = $allele =~ /(\S+)\(([^\)]+)\)/) {
                  my $expression = $data->{expression};

                  if ($name eq 'noname') {
                    if (grep {
                      $_ eq $description;
                    } qw(overexpression endogenous knockdown)) {
                      if ($expression && lc $expression ne lc $description) {
                        die "can't have $expression AND allele=$name($description)\n";
                      } else {
                        $data->{expression} = ucfirst $description;
                        $description = 'wild type';
                      }
                    }
                  }

                  my $allele_type = allele_type_from_desc($description);

                  if (!$allele_type) {
                    warn "can't guess allele type for $allele\n";
                    next;
                  }

                  my $new_allele =
                    $curs_schema->resultset('Allele')
                      ->create({
                        name => $name,
                        description => $description,
                        type => $allele_type,
                        gene => $gene->gene_id(),
                      });

                  my $allele_annotation_create_sth =
                    $curs_dbh->prepare("insert into allele_annotation (allele, annotation) " .
                                       "values (?, ?)");
                  $allele_annotation_create_sth->execute($new_allele->allele_id(),
                                                         $new_annotation->annotation_id());
                  $new_annotation->data($data);
                  $new_annotation->update();
                } else {
                  die "can't parse: $allele\n";
                }
              } else {
                $curs_schema->resultset('GeneAnnotation')
                  ->create({ gene => $gene, annotation => $new_annotation });
              }
            }

            $curs_dbh->do("DELETE FROM gene_annotation WHERE annotation = " . $annotation->annotation_id());
            $curs_dbh->do("DELETE FROM annotation WHERE annotation_id = " . $annotation->annotation_id());
          }
        }
      }

      my $genotype_manager = Canto::Curs::GenotypeManager->new(config => $config,
                                                               curs_schema => $curs_schema);

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
       background text,
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

      my @annotation_and_allele_data = ();

      my $annotation_rs = $curs_schema->resultset('Annotation');

      my %seen_genotype_names = ();

      while (defined (my $annotation = $annotation_rs->next())) {
        my $alleles_sth = $curs_dbh->prepare("select allele from allele_annotation where annotation = ?");

        $alleles_sth->execute($annotation->annotation_id());

        while (my ($allele_id) = $alleles_sth->fetchrow_array()) {
          my $allele = $curs_schema->resultset('Allele')->find({ allele_id => $allele_id });

          push @annotation_and_allele_data,
            {
              annotation => $annotation,
              allele_data => {
                primary_identifier => $allele->primary_identifier(),
                type => $allele->type(),
                description => $allele->description(),
                name => $allele->name(),
                gene => $allele->gene(),
              },
            };

          my $allele_annotation_delete_sth =
            $curs_dbh->prepare("delete from allele_annotation where allele = ? and " .
                               "annotation = ?");

          $allele_annotation_delete_sth->execute($allele_id, $annotation->annotation_id());
          $allele_annotation_delete_sth->finish();

          $allele->delete();
        }
      }

      my %new_alleles = ();

      for my $annotation_and_allele (@annotation_and_allele_data) {
        my $annotation = $annotation_and_allele->{annotation};
        my $allele_data = $annotation_and_allele->{allele_data};

        my $data = $annotation->data();
        my $expression = delete $data->{expression};

        if ($expression) {
          warn "    moved '$expression'\n";
          $allele_data->{expression} = $expression;

          $annotation->data($data);
          $annotation->update();
        }

        if ($allele_data->{type} eq 'unknown' &&
            $allele_data->{description} eq 'deletion') {
          warn "    allele " . ($allele_data->{name} // 'no_name') .
            " with type 'unknown' has description 'deletion'\n";
        }

        my $key = ($allele_data->{primary_identifier} // 'no_primary_id') . '-' .
          ($allele_data->{name} // 'no_name') . '-' .
          ($allele_data->{description} // 'no_description') . '-' .
          ($allele_data->{type} // 'no_type') . '-' .
          ($allele_data->{expression} // 'no_expression') . '-' .
          $allele_data->{gene}->primary_identifier();

        die "unexpected primary_identifier" if $allele_data->{primary_identifier};

        my $annotation_genotype;
        my $annotation_allele;

        if ($new_alleles{$key}) {
          ($annotation_genotype, $annotation_allele) = @{$new_alleles{$key}};
        } else {
          $annotation_allele = $curs_schema->resultset('Allele')->create($allele_data);

          my $annotation_allele_primary_identifier =
            $allele_data->{gene}->primary_identifier() . ":$curs_key-" . $annotation_allele->allele_id();

          $annotation_allele->primary_identifier($annotation_allele_primary_identifier);
          $annotation_allele->update();

          my $genotype_name = $allele_data->{gene}->primary_identifier() .
            '-' . $annotation_allele->long_identifier();

          if (exists $seen_genotype_names{$genotype_name}) {
            my $extra_index = 2;

            while (exists $seen_genotype_names{$genotype_name . "-$extra_index"}) {
              $extra_index++;
            }

            $genotype_name .= "-$extra_index";
          }

          warn "  making new genotype: $genotype_name  from allele: $key\n";

          my $background = '';

          $annotation_genotype = $genotype_manager->make_genotype($curs_key, $genotype_name, $background,
                                                        [$annotation_allele]);

          $seen_genotype_names{$genotype_name} = 1;

          $new_alleles{$key} = [$annotation_genotype, $annotation_allele];
        }

        my $insert_sth =
          $curs_dbh->prepare("insert into genotype_annotation(genotype, annotation) " .
                               "values (?, ?)");
        $insert_sth->execute($annotation_genotype->genotype_id(), $annotation->annotation_id());
        $insert_sth->finish();
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
