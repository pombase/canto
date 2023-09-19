#!/usr/bin/env perl

# merge duplicate alleles
# See: https://github.com/pombase/canto/issues/2642

use strict;
use warnings;
use Carp;

use File::Basename;

use open ':std', ':encoding(UTF-8)';

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    chdir "..";
  }
};

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
my $schema = Canto::TrackDB->new(config => $config);

my $track_schema = Canto::TrackDB->new(config => $config);

my $chado_schema = Canto::ChadoDB->new(config => $config);

sub safe_str_eq
{
  my $undef_str = '____:::UNDEF:::____';
  my $first = shift // $undef_str;
  my $second = shift // $undef_str;

  return $first eq $second;
}

sub safe_num_eq
{
  my $first = shift;
  my $second = shift;

  if (defined $first && defined $second) {
    return $first == $second;
  } else {
    if (!defined $first && !defined $second) {
      return 1;
    } else {
      return 0;
    }
  }
}

my %all_genes = ();

my $gene_rs =
  $chado_schema->resultset('Feature')
  ->search({ 'type.name' => 'gene' }, { join => ['type'] });

while (defined (my $gene = $gene_rs->next())) {
  my $gene_uniquename = $gene->uniquename();
  my $gene_name = $gene->name();

  if (defined $gene_name) {
    $all_genes{$gene_uniquename} = {
      name => $gene_name,
    };
  }
}


my %gene_synonyms = ();

my $gene_synonym_rs =
  $chado_schema->resultset('FeatureSynonym')
  ->search({ 'type.name' => 'gene' },
           {
             join => [{ feature => 'type' }, 'synonym'],
             prefetch => [ 'feature', 'synonym' ],
           });

while (defined (my $gene_synonym = $gene_synonym_rs->next())) {
  my $gene = $gene_synonym->feature();
  my $synonym = $gene_synonym->synonym();

  my @current_synonyms = ();

  if ($gene_synonyms{$gene->uniquename()}) {
    @current_synonyms = @{$gene_synonyms{$gene->uniquename()}};
  } else {
    $gene_synonyms{$gene->uniquename()} = [];
  }

  if (!grep { $_ eq $synonym->name() } @current_synonyms) {
    push @{$gene_synonyms{$gene->uniquename()}}, $synonym->name();
  }
}

sub merge_alleles
{
  my $survivor_allele_detail = shift;
  my $allele_details = shift;
  my @allele_details = @$allele_details;

  my $survivor_allele_id = $survivor_allele_detail->{allele_id};

  my @alleles_for_deletion = ();

  for my $allele_detail (@allele_details) {
    next if $allele_detail->{allele_id} == $survivor_allele_detail->{allele_id};

    my $allele_id = $allele_detail->{allele_id};
    my $db_allele = $allele_detail->{db_allele};

    print "merging $allele_id into $survivor_allele_id\n";

    if ($allele_detail->{db_allele}->allelesynonyms()->count() > 0) {
      print "  $allele_id has synonyms but will be removed\n";
      die;
    }

    my $allele_genotypes_rs = $allele_detail->{db_allele}->allele_genotypes();

    while (defined (my $allele_genotype = $allele_genotypes_rs->next())) {
      $allele_genotype->allele($survivor_allele_id);
      $allele_genotype->update();
    }

    push @alleles_for_deletion, $db_allele;
  }

  print scalar(@alleles_for_deletion), " for deletion\n";

  for my $allele_for_deletion (@alleles_for_deletion) {
    print "deleting: \n";
    print "  ", $allele_for_deletion->allele_id(), "\n";

    $allele_for_deletion->allele_genotypes()->delete();
    $allele_for_deletion->delete();
  }
}

sub merge_genotypes
{
  my $allele_detail = shift;

  my $db_allele = $allele_detail->{db_allele};

  my $allele_genotypes_rs = $db_allele->allele_genotypes()
    ->search({}, { prefetch => ['genotype'] });

  my @allele_genotypes_to_merge = ();

  while (defined (my $allele_genotype = $allele_genotypes_rs->next())) {
    my $genotype = $allele_genotype->genotype();

    if ($genotype->allele_genotypes()->count() == 1) {
      push @allele_genotypes_to_merge, $allele_genotype;
    }
  }

  if (@allele_genotypes_to_merge >= 2) {
    use Data::Dumper;
    $Data::Dumper::Maxdepth = 2;
    print 'merging: ', Dumper([$allele_detail]);

    print "  ", scalar(@allele_genotypes_to_merge), " genotypes\n";

    my $first_allele_genotype = shift @allele_genotypes_to_merge;
    my $first_genotype = $first_allele_genotype->genotype();

    for my $other_allele_genotype (@allele_genotypes_to_merge) {
      my $other_genotype = $other_allele_genotype->genotype();

      if (!safe_str_eq($first_genotype->name(),
                       $other_genotype->name())) {
        print "  not merging: name\n";
        next;
      }

      if (!safe_str_eq($first_genotype->background(),
                       $other_genotype->background())) {
        print "  not merging: background\n";
        next;
      }

      if (!safe_str_eq($first_genotype->comment(),
                       $other_genotype->comment())) {
        print "  not merging: comment\n";
        next;
      }

      if (!safe_num_eq($first_genotype->organism_id(),
                       $other_genotype->organism_id())) {
        print "  not merging: organism_id\n";
        next;
      }

      if (!safe_num_eq($first_genotype->strain_id(),
                       $other_genotype->strain_id())) {
        print "  not merging: strain_id\n";
        next;
      }

      print "    replace allele genotype ",
        $other_allele_genotype->allele_genotype_id(), " with ",
        $first_allele_genotype->allele_genotype_id(), "\n";
      print "    replace genotype ",
        $other_genotype->genotype_id(), " with ",
        $first_genotype->genotype_id(), "\n";

      $other_allele_genotype->delete();

      my $genotype_annotations_rs =
        $other_genotype->genotype_annotations();

      while (defined (my $genotype_annotation = $genotype_annotations_rs->next())) {
        $genotype_annotation->genotype($first_genotype);
        $genotype_annotation->update();
      }

      $other_genotype->delete();
    }
  }
}


### CHECK:
#
# 30da765280e4ffe0 - cdc13+ - wild type - [NO_DESCRIPTION] - Knockdown - SPBC582.03
#   1 - cdc13+ - cdc13 - wild type - [NO_DESCRIPTION] - [NOT_ASSAYED]
#     2 genotypes
#   8 - cdc13+ - cdc13 - wild type - [NO_DESCRIPTION] - [NOT_ASSAYED]
#     1 genotypes
# merging 8 into 1
# 1 for deletion
# deleting:
#   8
# merging:
#   2 genotypes  cdc2-33


my $proc = sub {
  my $curs = shift;
  my $cursdb = shift;
  my $curs_key = $curs->curs_key();

  my $curs_dbh = $cursdb->storage()->dbh();
  my $metadata_sth =
    $curs_dbh->prepare("select value from metadata where key = ? OR key = ?");

  $metadata_sth->execute('needs_approval_timestamp', 'session_created_timestamp');

  my ($timestamp) = $metadata_sth->fetchrow_array();

  if ($timestamp) {
    $timestamp =~ s/ .*//;
  } else {
    $timestamp = '[UKNOWN_DATE]';
  }

  my $allele_rs = $cursdb->resultset('Allele')
      ->search({}, { prefetch => [ 'gene', ] });

  my %seen_alleles_by_key = ();

  while (defined (my $allele = $allele_rs->next())) {
    my $gene = $allele->gene();

    my $allele_name = $allele->name() // '[UNNAMED]';

    my $allele_type = $allele->type() // '[NO_TYPE]';
    my $allele_description = $allele->description() // '[NO_DESCRIPTION]';
    my $allele_expression = $allele->expression() // '[NOT_ASSAYED]';

    my $gene_uniquename = $gene->primary_identifier();
    my $gene_details = $all_genes{$gene_uniquename};

    my $gene_name = undef;

    if (defined $gene_details && defined $gene_details->{name}) {
      $gene_name = $gene_details->{name};
    }

    if ($allele->type() eq 'deletion') {
      if ($gene_name) {
        $allele_name = $gene_name . 'delta';
      } else {
        $allele_name = $gene_uniquename . 'delta';
      }
    }

    my $allele_key = $allele_name . ' - ' .
      $allele_type . ' - ' .
      $allele_description . ' - ' .
      $allele_expression . ' - ' .
      $gene->primary_identifier();

#    print "$curs_key - $timestamp - $allele_key\n";

    push @{$seen_alleles_by_key{$allele_key}}, {
      allele_id => $allele->allele_id(),
      db_allele => $allele,
      name => $allele->name(),
      type => $allele->type(),
      description => $allele->description(),
      gene_uniquename => $gene->primary_identifier(),
      gene_name => $gene_name,
    };
  }

  while (my ($key, $allele_details) = each %seen_alleles_by_key) {
    if (@$allele_details > 1) {

      print "$curs_key - $key\n";

      my $survivor_allele_detail;

      if ($allele_details->[0]->{type} eq 'deletion') {
        for my $allele_detail (@$allele_details) {
          my $allele_name = $allele_detail->{name};
          my $gene_name = $allele_detail->{gene_name};

          if ($gene_name && $allele_name eq $gene_name . 'delta') {
            $survivor_allele_detail = $allele_detail;
            last;
          }
        }

        if (!defined $survivor_allele_detail) {
          for my $allele_detail (@$allele_details) {
            my $allele_name = $allele_detail->{name};
            my $gene_name = $allele_detail->{gene_name};

            my $gene_uniquename = $allele_detail->{gene_uniquename};
            if ($allele_name eq $gene_uniquename . 'delta') {
              $survivor_allele_detail = $allele_detail;
              last;
            }
          }
        }
      } else {
        $survivor_allele_detail = $allele_details->[0];
      }

      if (!defined $survivor_allele_detail) {
        print "no survivor candidate found for: $key\n";
        $survivor_allele_detail = $allele_details->[0];
        print "  using ", $survivor_allele_detail->{allele_id}, "\n";
      }

    ALLELE_DETAIL:
      for my $allele_detail (@$allele_details) {
        my $allele_name = $allele_detail->{name};
        my $allele_type = $allele_detail->{type};
        my $gene_name = $allele_detail->{gene_name};
        my $gene_uniquename = $allele_detail->{gene_uniquename};
        my $db_allele = $allele_detail->{db_allele};
        my @allele_genotypes = $db_allele->allele_genotypes()->all();

        print "  ", $allele_detail->{allele_id}, " - ",
          ($allele_name // '[NO_NAME]'), " - ",
          ($gene_name // '[NO_GENE_NAME]'), " - ",
          $allele_type, " - ",
          ($allele_detail->{description} // '[NO_DESCRIPTION]'), " - ",
          ($allele_detail->{expression} // '[NOT_ASSAYED]'), "\n";

        if ($db_allele->allele_notes()->count() > 0) {
          print "    HAS NOTES\n";
        }

        print "    ", scalar(@allele_genotypes), " genotypes\n";

        if ($allele_name &&
            ($allele_type eq 'deletion' || $allele_type eq 'wildtype' ||
             $allele_type eq 'disruption')) {
          my @possible_names = ($gene_uniquename);

          if ($gene_name) {
            push @possible_names, $gene_name;
          }

          my $gene_synonyms = $gene_synonyms{$gene_uniquename};

          if (defined $gene_synonyms) {
            for my $gene_synonym (@$gene_synonyms) {
              if (!grep { $_ eq $gene_synonym } @possible_names) {
                push @possible_names, $gene_synonym;
              }
            }
          }

          for my $possible_name (@possible_names) {
            if ($allele_name =~ /^$possible_name(delta|\+|\:\:ura4\+?)$/) {
              next ALLELE_DETAIL;
            }
          }

          print "    fixme: ", ($allele_detail->{name} // '[NO_NAME]'),
            " ", ($gene_name ? " $gene_name" : ""), " $gene_uniquename\n";

        }
      }

      merge_alleles($survivor_allele_detail, $allele_details);

      merge_genotypes($survivor_allele_detail);

      print "\n";
    }
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);
