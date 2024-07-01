#!/usr/bin/env perl

# Create genotype-genotype interactions from double allele mutants
#
# See: https://github.com/pombase/pombase-chado/issues/692

use strict;
use warnings;
use Carp;

use utf8;

use File::Basename;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use Canto::Config;
use Canto::Track;
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

push @{$config->{export_type_to_allele_type}->{nonsense_mutation}}, { name => 'nonsense mutation' };

my $track_schema = Canto::TrackDB->new(config => $config);

use utf8; use Canto::Track::OntologyLookup;

my $lookup = Canto::Track::get_adaptor($config, "ontology");


BEGIN { binmode STDOUT, ":encoding(UTF-8)"; }

sub is_pop {
  my $a = shift;
  my $ag_rs = $a->genotypes();

  for my $single_allele_genotype ($ag_rs->all()) {
    return undef unless $single_allele_genotype->alleles()->count() == 1;

    for my $single_allele_genotype_annotation ($single_allele_genotype->annotations()) {

      my $term_ontid = $single_allele_genotype_annotation->data()->{term_ontid};
      my $res = $lookup->lookup_by_id(id => $term_ontid, include_subset_ids => 1);

      if (grep { $_ eq 'is_a(FYPO:0002057)' } @{$res->{subset_ids}}) {
        return $single_allele_genotype;
      }
    }
  }

  die "not pop\n";

  return undef;
};


sub make_key
{
  my $evidence = shift;
  my $genotype_annotation = shift;
  my $allele_1_genotype = shift;
  my $allele_2_genotype = shift;

  my $data = $genotype_annotation->annotation->data();

  my $annotation_key =
    join ('---',
          $genotype_annotation->genotype->display_name($config),
          $genotype_annotation->annotation->type(),
          $data->{term_ontid});

  return join (':-:',$evidence,
               $annotation_key,
               $allele_1_genotype->display_name($config),
               $allele_2_genotype->display_name($config));
}

sub make_interaction {
  my ($curs_schema, $interaction_type,
      $double_mutant_genotype_annotation, $allele_1_genotype,
      $allele_2_genotype) = @_;

  my %create_args = (
    interaction_type => $interaction_type,
    primary_genotype_annotation_id =>
      $double_mutant_genotype_annotation->genotype_annotation_id(),
    genotype_a_id => $allele_1_genotype->genotype_id(),
    genotype_b_id => $allele_2_genotype->genotype_id(),
  );

  $curs_schema->create_with_type('GenotypeInteraction', \%create_args);
}

my %created_interactions = ();

my $proc = sub {
  my $curs = shift;
  my $curs_schema = shift;
  my $track_schema = shift;

  my $rs = $curs_schema->resultset("Annotation")
    ->search({ type => "phenotype" });

  while (defined (my $an = $rs->next())) {
    my $data = $an->data();
    next unless $data->{term_ontid} eq "FYPO:0002061";
    my $genotype_annotations_rs = $an->genotype_annotations();
    my $genotype_annotation = $genotype_annotations_rs->first();

    if ($genotype_annotation->genotype_interactions()->count() > 0) {
      next;
    }

    my $double_allele_genotype = $genotype_annotation->genotype();
    my $alleles_rs = $double_allele_genotype->alleles();
    next unless $alleles_rs->count() == 2;
    my $allele_1 = $alleles_rs->next();
    next unless $allele_1->type() eq "deletion";
    my $allele_1_genotype = is_pop($allele_1);
    next unless defined $allele_1_genotype;
    my $allele_2 = $alleles_rs->next();
    next unless $allele_2->type() eq "deletion";
    my $allele_2_genotype = is_pop($allele_2);
    next unless defined $allele_2_genotype;

    my $seen_key = make_key('Synthetic Growth Defect',
                            $genotype_annotation, $allele_1_genotype,
                            $allele_2_genotype);

    if ($created_interactions{$seen_key}) {
      next;
    } else {
      $created_interactions{$seen_key} = 1;
    }

    print $curs->curs_key(), "\n";
    make_interaction($curs_schema, 'Synthetic Growth Defect',
                     $genotype_annotation, $allele_1_genotype,
                     $allele_2_genotype);
  }
};

my $transaction = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($transaction);


