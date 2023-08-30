package Canto::Chado::GenotypeInteractionLookup;

=head1 NAME

Canto::Chado::GenotypeInteractionLookup - lookup genotype-genotype interactions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Chado::GenotypeInteractionLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2022 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use feature "state";

use Carp;
use Moose;

use CHI;

use LWP::UserAgent;

use Canto::Cache;


with 'Canto::Role::Configurable';
with 'Canto::Chado::ChadoLookup';
#with 'Canto::Role::TaxonIDLookup';

has cache => (is => 'ro', init_arg => undef, lazy_build => 1);

sub _build_cache
{
  my $self = shift;

  my $cache = Canto::Cache::get_cache($self->config(), __PACKAGE__);


  return $cache;
}

=head2

 Usage   : my $res = Canto::Chado::GenotypeInteractionLookup($options);
 Function: lookup genotype-genotype interaction annotations in a Chado database
 Args    : $options->{pub_uniquename} - the identifier of the publication,
               usually the PubMed ID to get annotations for
           $options->{gene_identifier} - the gene identifier to use to constrain
               the search; only annotations for the gene are returned (optional)
           $options->{max_results} - maximum number of interactions to return
 Returns : A count of annotations and an array reference of annotation results:
            (1,
            [ {
              annotation_id => ...,
              gene_a => {
                identifier => "SPAC22F3.13",
                name => 'tsc1',
                organism_taxonid => 4896
              },
              genotype_a => {
                identifier => '...',
                display_name => '...',
              },
              publication => {
                uniquename => 'PMID:10467002',
              },
              interaction_type => 'Phenotypic Enhancement',
              gene_b => { ... },
              genotype_b => {
                identifier => '...',
                display_name => '...',
              },
            }, ... ])
          - where annotation_id is a unique ID for this annotation

=cut
sub lookup
{
  my $self = shift;
  my $args_ref = shift;
  my %args = %{$args_ref};


  my $pub_uniquename = $args{pub_uniquename};
  my $gene_identifier = $args{gene_identifier};
  my $interaction_type_name = $args{interaction_type_name};
  my $max_results = $args{max_results} // 0;

  my $cache_key;

  if (defined $gene_identifier) {
    $cache_key = "$pub_uniquename!$gene_identifier!$interaction_type_name!$max_results";
  } else {
    $cache_key = "$pub_uniquename!$interaction_type_name!$max_results";
  }

  my $cached_value = $self->cache->get($cache_key);

  if (defined $cached_value) {
    return @$cached_value;
  }

  my $url = $self->config()->{webservices}->{pombase_api_base_url} .
    '/reference/' . $pub_uniquename;

  my $ua = LWP::UserAgent->new;
  $ua->default_header('Accept', 'text/plain');
  my $res = $ua->get($url);

  if ($res->status_line() =~ /^404\s.*/) {
    return (0, []);
  }

  if (!$res->is_success && $res->status_line() !~ /^404\s.*/) {
    warn $res->status_line();
    return (0, []);
  }

  my $content = $res->decoded_content();

  my $pub_details = JSON->new->utf8(0)->decode($content);

  my $genotypes_by_uniquename = $pub_details->{genotypes_by_uniquename};
  my $genes_by_uniquename = $pub_details->{genes_by_uniquename};
  my $terms_by_termid = $pub_details->{terms_by_termid};
#  my $alleles_by_uniquename = $pub_details->{alleles_by_uniquename};

  my @pub_interactions = @{$pub_details->{genetic_interactions} // []};

  my $_process_extension_for_canto = sub {
    my $ext_from_api = shift;

    map {
      my $ext_part = $_;

      my $ext_range = $ext_part->{ext_range};

      my $term = $ext_range->{termid};

      if ($term && $terms_by_termid->{$term}) {
        $term = $terms_by_termid->{$term}->{name};
      }

      my $gene = $ext_range->{gene_uniquename};

      if ($gene && $genes_by_uniquename->{$gene} &&
          $genes_by_uniquename->{$gene}->{name}) {
        $gene = $genes_by_uniquename->{$gene}->{name};
      }

      my $range_value = $gene //
        $term //
        $ext_range->{transcript_uniquename} //
        $ext_range->{misc} //
        $ext_range->{domain} //
        $ext_range->{gene_product};

      {
        relation => $ext_part->{rel_type_name},
        rangeDisplayName => $range_value,
      }
    } @$ext_from_api;
  };

  my $_process_interaction_with_detail = sub {
    my ($gene_a_uniquename, $interaction_type,
        $gene_b_uniquename, $detail) = @_;

    my $genotype_a_uniquename = $detail->{genotype_a_uniquename};
    my $genotype_b_uniquename = $detail->{genotype_b_uniquename};

    if (!defined $genotype_a_uniquename || !defined $genotype_b_uniquename) {
      return ();
    }

    my $genotype_a = $genotypes_by_uniquename->{$genotype_a_uniquename};
    my $genotype_b = $genotypes_by_uniquename->{$genotype_b_uniquename};

    my $double_mutant_termid = $detail->{double_mutant_phenotype_termid};
    my $double_mutant_term = $terms_by_termid->{$double_mutant_termid};

    my $double_mutant_extension = $detail->{double_mutant_extension};
    my $double_mutant_extension_for_canto = [];

    if ($double_mutant_extension) {
      $double_mutant_extension_for_canto =
          [ [$_process_extension_for_canto->($double_mutant_extension)] ];
    }

    my $rescued_phenotype_termid = $detail->{rescued_phenotype_termid};
    my $rescued_phenotype = undef;

    if (defined $rescued_phenotype_termid) {
      $rescued_phenotype = $terms_by_termid->{$rescued_phenotype_termid};
    }

    my %res = (
      status => 'existing',
      genotype_a => {
        display_name => $genotype_a->{display_name},
      },
      interaction_type => $interaction_type,
      genotype_b => {
        display_name => $genotype_b->{display_name},
      },
      double_mutant_termid => $detail->{double_mutant_phenotype_termid},
      term_name => $double_mutant_term->{name},
      double_mutant_term_name => $double_mutant_term->{name},
      double_mutant_phenotype_extension => $double_mutant_extension_for_canto,
      genotype_a_phenotype_annotations => [],
    );

    if ($rescued_phenotype) {
      my $rescued_phenotype_extension = $detail->{rescued_phenotype_extension};

      my $extension_for_canto = [];

      my $genotype_a_phenotype_annotation = {
        term_name => $rescued_phenotype->{name},
      };

      if ($rescued_phenotype_extension) {
        $genotype_a_phenotype_annotation->{extension} =
          [ [$_process_extension_for_canto->($rescued_phenotype_extension)] ];
      }

      push @{$res{genotype_a_phenotype_annotations}}, $genotype_a_phenotype_annotation;
    }

    \%res;
  };

  my $_process_interaction = sub {
    my $pub_interaction = shift;

    my $group_key = $pub_interaction->[0];
    my $gene_a_uniquename = $group_key->{gene_a_uniquename};
    my $interaction_type = $group_key->{interaction_type};
    my $gene_b_uniquename = $group_key->{gene_b_uniquename};

    my @details = @{$pub_interaction->[1]};

    map {
      my $detail = $_;
      $_process_interaction_with_detail->($gene_a_uniquename, $interaction_type,
                                          $gene_b_uniquename, $detail);
    } @details;
  };

  my @processed_interactions =
    map {
      $_process_interaction->($_);
    } @pub_interactions;

  my $all_interactions_count = scalar(@processed_interactions);

  my @ret_val = ($all_interactions_count, \@processed_interactions);

  $self->cache()->set($cache_key, \@ret_val, "2 hours");

  return @ret_val;
}

1;
