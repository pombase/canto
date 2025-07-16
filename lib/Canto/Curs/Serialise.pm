package Canto::Curs::Serialise;

=head1 NAME

Canto::Curs::Serialise - Code for serialising and de-serialising a CursDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::Serialise

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use feature 'state';

use JSON;
use Clone qw(clone);
use Data::Rmap ':all';

use Canto::Track::CuratorManager;
use Canto::Track;

our $ORCID_RE = qr/\d\d\d\d-\d\d\d\d-\d\d\d\d-\d\d\d[\dX]/;

sub _get_metadata_value
{
  my $schema = shift;
  my $key = shift;
  my $value = shift;

  if ($key eq 'curation_pub_id') {
    return $schema->find_with_type('Pub', $value)->uniquename();
  }

  return $value;
}

sub _get_metadata
{
  my $config = shift;
  my $track_schema = shift;
  my $curs_schema = shift;
  my $options = shift;

  confess("curs_schema not defined") unless defined $curs_schema;

  my @results = $curs_schema->resultset('Metadata')->all();

  my $curator_name_re = qr/(curator|approver|initial_curator|first_contact)_name$/;

  my $approver_orcid = undef;

  my %ret = map {
    my $key = $_->key();
    $key = "canto_session" if $key eq "curs_key";

    ($key, _get_metadata_value($curs_schema, $_->key(), $_->value() ))
  } grep {
    my $key = $_->key();
    if ($key eq 'approver_email' && $options->{export_curator_names}) {
      my $approver_email = $_->value();

      my $orcid_rs = $track_schema->resultset('Person')
        ->search({ email_address => $approver_email });

      my $person = $orcid_rs->next();

      if (defined $person && $person->orcid()) {
        $approver_orcid = $person->orcid();
      }
    }

    $key !~ /email$/ &&
      ($options->{export_curator_names} ||
       $key !~ /$curator_name_re/)
  } @results;

  if (defined $approver_orcid) {
    $ret{approver_orcid} = $approver_orcid;
  }

  if (!$ret{canto_session}) {
    warn "can't for curs_key in CursDB metadata\n";
    confess();
  }

  my $curs_obj =
    $track_schema->resultset('Curs')->find({ curs_key => $ret{canto_session} });

  if (!defined $curs_obj) {
    warn "can't find Curs object for ", $ret{canto_session}, " in TrackDB\n";
    confess();
  }

  my $cursprops_rs = $curs_obj->cursprops();

  while (defined (my $prop = $cursprops_rs->next())) {
    my $prop_type_name = $prop->type()->name();

    next if $prop_type_name =~ /email$/;

    next if !$options->{export_curator_names} &&
      $prop_type_name && $prop_type_name =~ /$curator_name_re/;

    my $prop_value = $prop->value();

    if ($prop_type_name eq 'link_sent_to_curator_date' &&
          !defined $ret{first_sent_to_curator_date}) {
      $ret{first_sent_to_curator_date} = $prop_value;
    }
    $ret{$prop_type_name} = $prop_value;
  }

  my $curator_manager =
    Canto::Track::CuratorManager->new(config => $config);

  my ($current_submitter_email, $current_submitter_name,
      $known_as, $accepted_date, $community_curated) =
    $curator_manager->current_curator($ret{canto_session});

  my @all_curators = $curator_manager->session_curators($ret{canto_session});

  if ($options->{export_curator_names}) {
    $ret{initial_curator_name} = $all_curators[0]->[1];

    if (defined $current_submitter_name) {
      $current_submitter_name =~ s/\s+$//;
      $current_submitter_name =~ s/^\s+//;

      $ret{curator_name} = $current_submitter_name;

      if (@all_curators > 1) {
        my %seen_prev_curator_name = ($current_submitter_name, 1);
        $ret{previous_curators} =
          [map {
            my ($prev_email_address, $prev_curator_name) = @$_;
            $prev_curator_name =~ s/\s+$//;
            $prev_curator_name =~ s/^\s+//;
            if ($seen_prev_curator_name{$prev_curator_name}) {
              ();
            } else {
              $seen_prev_curator_name{$prev_curator_name} = 1;
              {
                curator_name => $prev_curator_name,
              }
            }
          } @all_curators];
      }
    }
  }

  $ret{curator_role} = $community_curated ? 'community' : $config->{database_name};
  $ret{curation_accepted_date} = $accepted_date;

  return \%ret;
}

sub _get_metagenotype_by_id
{
  my $schema = shift;
  my $metagenotype_id = shift;

  return $schema->resultset('Metagenotype')
    ->find({ metagenotype_id => $metagenotype_id });
}


sub _get_genotype_interactions_no_phenotype
{
  my $annotation = shift;

  my $interaction_rs = $annotation->genotype_annotations()
    ->search_related('genotype_interactions')
    ->search({},
                {
                  prefetch => ['genotype_a', 'genotype_b'],
                });

  my @interactions = ();

  while (defined (my $interaction_row = $interaction_rs->next())) {
    my $genotype_a = $interaction_row->genotype_a();
    my $genotype_b = $interaction_row->genotype_b();

    push @interactions,
      {
        interaction_type => $interaction_row->interaction_type(),
        genotype_a => $genotype_a->identifier(),
        genotype_b => $genotype_b->identifier(),
      };
  }

  return @interactions;
}

sub _get_genotype_interactions_with_phenotype
{
  my $annotation = shift;

  my $interaction_rs = $annotation->genotype_annotations()
    ->search_related('genotype_interactions_with_phenotype_primary_genotype_annotation')
    ->search({},
                {
                  prefetch => [
                    {
                      genotype_annotation_a => [
                        ['genotype', 'annotation'],
                      ]
                    },
                    'genotype_b'
                  ],
                });

  my @interactions = ();

  while (defined (my $interaction_row = $interaction_rs->next())) {
    my $genotype_annotation_a = $interaction_row->genotype_annotation_a();
    my $genotype_a = $genotype_annotation_a->genotype();
    my $genotype_b = $interaction_row->genotype_b();

    my $genotype_annotation_a_annotation = $genotype_annotation_a->annotation();

    my $annotation_a_data = $genotype_annotation_a_annotation->data();

    my $phenotype_termid = $annotation_a_data->{term_ontid};


    push @interactions,
      {
        interaction_type => $interaction_row->interaction_type(),
        genotype_a => $genotype_a->identifier(),
        genotype_b => $genotype_b->identifier(),
        genotype_a_phenotype_termid => $phenotype_termid,
        genotype_a_phenotype_extension => $annotation_a_data->{extension},
      };
  }

  return @interactions;
}

sub _get_annotations
{
  my $config = shift;
  my $track_schema = shift;
  my $schema = shift;
  my $options = shift;

  die "no schema" unless $schema;

  state $ontology_lookup = Canto::Track::get_adaptor($config, 'ontology');
  state $organism_lookup = Canto::Track::get_adaptor($config, 'organism');

  my $rs = $schema->resultset('Annotation');

  my @ret = ();

  while (defined (my $annotation = $rs->next())) {
    my %extra_data = %{clone $annotation->data()};

    if (defined $extra_data{interacting_genes}) {
      $extra_data{interacting_genes} =
        [
          map {
            my $interacting_gene =
              $schema->resultset('Gene')->find({
                primary_identifier => $_->{primary_identifier},
              });

            my $interacting_taxonid = $interacting_gene->organism()->taxonid();
            my $organism_details =
              $organism_lookup->lookup_by_taxonid($interacting_taxonid);
            my $full_name = $organism_details->{full_name};

            $full_name . ' ' . $_->{primary_identifier};
          } @{$extra_data{interacting_genes}}
        ]
    }

    my $term_ontid = delete $extra_data{term_ontid};
    if ($term_ontid) {
      $extra_data{term} = $term_ontid;
    }

    if ($extra_data{term_suggestion} &&
        !$extra_data{term_suggestion}->{name} &&
        !$extra_data{term_suggestion}->{definition}) {
      delete $extra_data{term_suggestion};
    }

    my %data = (
      status => $annotation->status(),
      publication => $annotation->pub->uniquename(),
      type => $annotation->type(),
      creation_date => $annotation->creation_date(),
      %extra_data,
    );

    if (defined $data{curator}) {
      if (defined $data{curator}->{community_curated}) {
        if ($data{curator}->{community_curated}) {
          # make sure that we have "true" in the JSON output, not "1"
          $data{curator}->{community_curated} = JSON::true;
        } else {
          $data{curator}->{community_curated} = JSON::false;
        }
      } else {
        my $metadata = _get_metadata($config, $track_schema, $schema, $options);
        die "community_curated not set for annotation ",
          $annotation->annotation_id(), " in session ",
          $metadata->{canto_session};
      }
      my $curator_orcid = $data{curator}->{curator_orcid};

      if (defined $curator_orcid && $curator_orcid =~ m|.*?($ORCID_RE)$|) {
        # remove any prefixes
        $data{curator}->{curator_orcid} = $1;
      } else {
        delete $data{curator}->{curator_orcid};
      }
    } else {
      my $metadata = _get_metadata($config, $track_schema, $schema, $options);
      die "community_curated not set for annotation ",
        $annotation->annotation_id(), " in session ",
        $metadata->{canto_session};
    }

    my $gene = _get_annotation_gene($organism_lookup, $schema, $annotation);
    my $genotype = _get_annotation_genotype($schema, $annotation);
    my $metagenotype = _get_annotation_metagenotype($schema, $annotation);

    if ($gene) {
      $data{gene} = $gene;
    }
    if ($genotype) {
      $data{genotype} = $genotype;
    }
    if ($metagenotype) {
      $data{metagenotype} = $metagenotype;
    }

    rmap_hash {
      my $current = $_;

      if (exists $current->{email}) {
        # curator section
        if (!$options->{export_curator_names}) {
          delete $current->{name};
        }
        cut();
      }

      delete $current->{curator_email};

      if (!$options->{export_curator_names}) {
        delete $current->{curator_name};
      }

      for my $key (keys %$current) {
        my $value = $current->{$key};
        if (defined $value) {
          if (!ref $value) {
            $current->{$key} =~ s/[[:^ascii:]]//g;
          }
        } else {
          $current->{$key} = '';
        }
      }
    } %data;


    my @genotype_interactions_no_phenotype =
      _get_genotype_interactions_no_phenotype($annotation);

    if (@genotype_interactions_no_phenotype) {
      $data{genotype_interactions_no_phenotype} = \@genotype_interactions_no_phenotype;
    }

    my @genotype_interactions_with_phenotype =
      _get_genotype_interactions_with_phenotype($annotation);

    if (@genotype_interactions_with_phenotype) {
      $data{genotype_interactions_with_phenotype} = \@genotype_interactions_with_phenotype;
    }

    if (!$data{extension} || @{$data{extension}} == 0) {
      push @ret, \%data;
    } else {
      my $extension = delete $data{extension};

      map {
        my $extension_part = $_;

        my $data_clone = clone \%data;
        $data_clone->{extension} = $extension_part;

        map {
          my $extension_bit = $_;

          if (defined $extension_bit->{rangeType}) {
            if (lc $extension_bit->{rangeType} eq 'metagenotype') {
              my $metagenotype =
                _get_metagenotype_by_id($schema, $extension_bit->{rangeValue});

              if ($metagenotype) {
                $extension_bit->{rangeValue} = $metagenotype->identifier();
              } else {
                $extension_bit->{rangeValue} = "MISSING_METAGENOTYPE";
              }

              my %metagenotype_details =
                Canto::Curs::Utils::make_metagenotype_details($schema, $metagenotype,
                                                              $config,
                                                              $ontology_lookup,
                                                              $organism_lookup);

              $extension_bit->{rangeDisplayName} =
                $metagenotype_details{metagenotype_display_name};
            }
          }
        } @$extension_part;

        push @ret, $data_clone
      } @$extension;
    }
  }

  return \@ret;
}

sub _get_annotation_gene
{
  my $organism_lookup = shift;
  my $schema = shift;
  my $annotation = shift;

  my $rs = $annotation->genes();
  my @ret = ();

  while (defined (my $gene = $rs->next())) {
    my $taxonid = $gene->organism()->taxonid();
    my $organism_details = $organism_lookup->lookup_by_taxonid($taxonid);
    my $organism_full_name = $organism_details->{full_name};

    push @ret, $organism_full_name . ' ' . $gene->primary_identifier();
  }

  if (@ret > 1) {
    die "internal error during export: annotation ",
      $annotation->annotation_id(),
      " has more than one gene";
  } else {
    return $ret[0];
  }
}

sub _get_genes
{
  my $organism_lookup = shift;
  my $schema = shift;

  my $rs = $schema->resultset('Gene');
  my %ret = ();

  while (defined (my $gene = $rs->next())) {
    my $taxonid = $gene->organism()->taxonid();
    my $organism_details = $organism_lookup->lookup_by_taxonid($taxonid);
    my $organism_full_name = $organism_details->{full_name};

    my %gene_data = (
      uniquename => $gene->primary_identifier(),
    );

    my $gene_key;

    if ($organism_full_name) {
      $gene_key = $organism_full_name . ' ' . $gene->primary_identifier();
      $gene_data{organism} = $organism_full_name;
    } else {
      $gene_key = $gene->primary_identifier();
    }

    $ret{$gene_key} = { %gene_data };
  }

  return %ret;
}

sub _get_genotype_loci
{
  my $config = shift;
  my $schema = shift;
  my $genotype = shift;

  my $organism_lookup = Canto::Track::get_adaptor($config, 'organism');

  my $rs = $schema->resultset('AlleleGenotype')
    ->search({ genotype => $genotype->genotype_id() },
             {
               prefetch => [ { allele => 'gene' }, 'diploid' ],
             });

  my @ret = ();

  my %non_haploids = ();

  while (defined (my $allele_genotype = $rs->next())) {
    my $allele = $allele_genotype->allele();
    my $gene = $allele->gene();

    if (!defined $allele->primary_identifier()) {
      warn "undefined primary_identifier: ", $allele->name(), "\n";
    }

    my %ret_hash = (
      id => $allele->primary_identifier(),
    );

    if ($allele->expression()) {
      $ret_hash{expression} = $allele->expression();
    }
    if ($allele->promoter_gene()) {
      $ret_hash{promoter_gene} = $allele->promoter_gene();
    }

    my $locus = $allele_genotype->diploid();

    if ($locus) {
      push @{$non_haploids{$locus->diploid_id()}}, \%ret_hash;
    } else {
      push @ret, [\%ret_hash];
    }
  }

  push @ret, values %non_haploids;

  return @ret;
}

sub _get_alleles
{
  my $config = shift;
  my $schema = shift;

  my $organism_lookup = Canto::Track::get_adaptor($config, 'organism');

  my $rs = $schema->resultset('Allele');

  my %ret = ();

  while (defined (my $allele = $rs->next())) {
    my $gene = $allele->gene();

    if (!$allele->primary_identifier()) {
      die 'no primary_identifier for allele with ID: ', $allele->allele_id();
    }

    my $key = $allele->primary_identifier();

    my $export_type =
      $config->{allele_types}->{$allele->type()}->{export_type};

    if (!defined $export_type) {
      $export_type = $allele->type();
    }

    my %allele_data = (
      allele_type => $export_type,
    );

    if ($gene) {
      my $taxonid = $gene->organism()->taxonid();

      my $organism_details = $organism_lookup->lookup_by_taxonid($taxonid);
      my $organism_full_name = $organism_details->{full_name};

      my $gene_key;

      if ($organism_full_name) {
        $gene_key = "$organism_full_name " . $gene->primary_identifier();
      } else {
        $gene_key = $gene->primary_identifier();
      }

      $allele_data{gene} = $gene_key;
    }

    if (defined $allele->primary_identifier()) {
      $allele_data{primary_identifier} = $allele->primary_identifier();
    }
    if (defined $allele->description()) {
      $allele_data{description} = $allele->description();
    }

    my $set_deletion_names_from_gene = 1;
    if ($config->{export} && $config->{export}->{canto_json} &&
        $config->{export}->{canto_json}) {
      $set_deletion_names_from_gene =
        $config->{export}->{canto_json}->{set_deletion_names_from_gene} // 1;
    }

    if ($allele->type() eq 'deletion' && $set_deletion_names_from_gene) {
      my $gene_proxy = Canto::Curs::GeneProxy->new(config => $config,
                                                   cursdb_gene => $gene);

      my $gene_name = $gene_proxy->primary_name();

      $allele_data{name} =
        ($gene_name // $gene->primary_identifier()) . 'delta';
    } else {
      if (defined $allele->name()) {
        $allele_data{name} = $allele->name();
      }
    }

    my $note_types = $config->{allele_note_types};

    if ($note_types && scalar(@{$note_types}) > 0) {
      $allele_data{notes} = {};

      my @notes = $allele->allele_notes()->all();

      map {
        my $note = $_;
        $allele_data{notes}->{$_->key()} = $_->value();
      } @notes;
    }

    my @allelesynonyms = $allele->allelesynonyms();

    my @export_synonyms = ();

    for my $synonym (@allelesynonyms) {
      if ($synonym->edit_status() eq 'new') {
        push @export_synonyms, $synonym->synonym();
      }
    }

    $allele_data{synonyms} = \@export_synonyms;

    $ret{$key} = \%allele_data;
  }

  return %ret;
}

sub _get_annotation_genotype
{
  my $schema = shift;
  my $annotation = shift;

  my @ret = map {
    $_->identifier();
  } $annotation->genotypes()->all();

  if (@ret > 1) {
    die "internal error during export: annotation ",
      $annotation->annotation_id(),
      " has more than one genotype";
  } else {
    return $ret[0];
  }
}

sub _get_annotation_metagenotype
{
  my $schema = shift;
  my $annotation = shift;

  my @ret = map {
    $_->identifier();
  } $annotation->metagenotypes()->all();

  if (@ret > 1) {
    die "internal error during export: annotation ",
      $annotation->annotation_id(),
      " has more than one metagenotype";
  } else {
    return $ret[0];
  }
}

sub _get_genotypes
{
  my $config = shift;
  my $schema = shift;

  my $rs = $schema->resultset('Genotype');
  my %ret = ();

  while (defined (my $genotype = $rs->next())) {
    my $genotype_identifier = $genotype->identifier();

    $ret{$genotype_identifier} = {
      loci => [_get_genotype_loci($config, $schema, $genotype)]
    };

    if ($genotype->organism()) {
      $ret{$genotype_identifier}->{organism_taxonid} = $genotype->organism()->taxonid();
    }

    my $strain = $genotype->strain();
    if (defined $strain) {
      my $strain_lookup = Canto::Track::StrainLookup->new(config => $config);
      $ret{$genotype_identifier}->{organism_strain} =
        $strain->lookup_strain_name($strain_lookup);
    }

    if ($genotype->name()) {
      $ret{$genotype_identifier}->{name} = $genotype->name(),
    }
    if ($genotype->background()) {
      $ret{$genotype_identifier}->{background} = $genotype->background(),
    }
    if ($genotype->comment()) {
      $ret{$genotype_identifier}->{comment} = $genotype->comment(),
    }
  }

  return %ret;
}

sub _get_metagenotypes
{
  my $config = shift;
  my $schema = shift;

  my $rs = $schema->resultset('Metagenotype',
                              { prefetch => ['first_genotype', 'second_genotype'] });
  my %ret = ();

  while (defined (my $metagenotype = $rs->next())) {
    if ($metagenotype->type() eq 'pathogen-host') {
      $ret{$metagenotype->identifier()} = {
        pathogen_genotype => $metagenotype->pathogen_genotype()->identifier(),
        host_genotype => $metagenotype->host_genotype()->identifier(),
      };
    } else {
      $ret{$metagenotype->identifier()} = {
        genotype_a => $metagenotype->first_genotype()->identifier(),
        genotype_b => $metagenotype->second_genotype()->identifier(),
      };
    }
    $ret{$metagenotype->identifier()}->{type} = $metagenotype->type();
  }

  return %ret;
}

sub _get_organisms
{
  my $config = shift;
  my $schema = shift;

  my $organism_lookup = Canto::Track::get_adaptor($config, 'organism');

  my $rs = $schema->resultset('Organism');
  my %ret = ();

  while (defined (my $organism= $rs->next())) {
    my $organism_details = $organism_lookup->lookup_by_taxonid($organism->taxonid());
    my $full_name = $organism_details->{full_name};
    $ret{$organism->taxonid()} = { full_name => $full_name };
  }

  return \%ret;
}

sub _get_pubs
{
  my $schema = shift;
  my $options = shift;

  my $rs = $schema->resultset('Pub');
  my %ret = ();

  while (defined (my $pub = $rs->next())) {
    if ($options->{all_data}) {
      $ret{$pub->uniquename()} = {
        title => $pub->title(),
      };
    } else {
      $ret{$pub->uniquename()} = { };
    }
  }

  return \%ret;
}

sub _get_curators_from_annotations
{
  my $curs_key = shift;
  my $curator_manager = shift;
  my $annotations_ref = shift;
  my @annotations = @$annotations_ref;

  my $has_community_annotation = JSON::false;

  my %annotation_curators = ();

  map {
    my $curator = $_->{curator};

    if (defined $curator) {
      if ($curator->{community_curated} == JSON::true) {
        $has_community_annotation = JSON::true;
      }
      my $name = $curator->{name};

      # we need the email for looking up the ORCID but we don't want to include
      # it in the JSON output
      my $curator_email = delete $curator->{email};

      if (defined $name) {
        $annotation_curators{$name}->{annotation_count}++;
        $annotation_curators{$name}->{community_curator} =
          $curator->{community_curated};

        my $curator_orcid = $curator->{curator_orcid};

        if (!defined $curator_orcid && defined $curator_email) {
          $curator_orcid =
            ($curator_manager->curator_details_by_email($curator_email))[3];
        }

        if (defined $curator_orcid) {
          if ($curator_orcid =~ m|.*?($ORCID_RE)$|) {
            # remove any prefixes
            $annotation_curators{$name}->{curator_orcid} = $1;
          } else {
            delete $annotation_curators{$name}->{curator_orcid};
          }
        }
      }
    }
  } @annotations;

  my @annotation_curators =
    map {
      my $name = $_;
      my $count = $annotation_curators{$name}->{annotation_count};
      my $community = $annotation_curators{$name}->{community_curator};
      my $orcid = $annotation_curators{$name}->{curator_orcid};

      {
        name => $name,
        annotation_count => $count,
        community_curator => $community,
        orcid => $orcid,
      };
    } sort keys %annotation_curators;

  return ($has_community_annotation, \@annotation_curators);
}


=head2 json

 Usage   : my $ser = Canto::Curs::Serialise::json($config, $track_schema,
                                                   $curs_key, $options);
 Function: Return a JSON representation of the given CursDB
 Args    : $config - the Canto::Config object
           $track_schema - the TrackDB
           $curs_key - the curs key to serialise
           $options - export options - see documentation for
             Canto::Track::Serialise::json()
 Returns : A JSON string

=cut
sub json
{
  my $config = shift;
  my $track_schema = shift;
  my $curs_key = shift;
  die if ref $curs_key or not defined $curs_key;
  my $options = shift;

  my $encoder = JSON->new()->pretty(1)->canonical(1);

  return $encoder->encode(perl($config, $track_schema, $curs_key, $options));
}

=head2 perl

 Usage   : my $serialised =
             Canto::Curs::Serialise::perl($config, $curs_schema, $options);
 Function: Return a Perl hash representating all the data in the given CursDB
 Args    : $config - the Canto::Config object
           $track_schema - the TrackDB
           $curs_key - the curs key to serialise
           $options - export options - see documentation for
             Canto::Track::Serialise::json()
 Returns : A Perl hashref

=cut
sub perl
{
  my $config = shift;
  my $track_schema = shift;
  my $curs_key = shift;
  my $options = shift;
  my $curs_status = shift;

  my $curator_manager =
    Canto::Track::CuratorManager->new(config => $config);

  my $curs_schema =
    Canto::Curs::get_schema_for_key($config, $curs_key,
                                    {
                                      cache_connection => 0,
                                    });

  # write the metadata for all sessions
  my %ret = (
    metadata => _get_metadata($config, $track_schema, $curs_schema, $options),
    publications => _get_pubs($curs_schema, $options),
  );

  if (($curs_status &&
         ($curs_status eq 'APPROVED' &&
          ($options->{dump_approved} || $options->{export_approved})))
        ||
      (!$options->{dump_approved} && !$options->{export_approved})) {
    # only write the annotations if the session is approved or we're writing
    # everything

    $ret{annotations} = _get_annotations($config, $track_schema, $curs_schema, $options);

    my ($has_community_annotation, $annotation_curators) =
      _get_curators_from_annotations($curs_key, $curator_manager,
                                     $ret{annotations});

    $ret{metadata}{has_community_curation} = $has_community_annotation;

    if ($options->{export_curator_names}) {
      $ret{metadata}{annotation_curators} = $annotation_curators;
    }

    $ret{organisms} = _get_organisms($config, $curs_schema, $options);

    my $organism_lookup = Canto::Track::get_adaptor($config, 'organism');

    my %genes = _get_genes($organism_lookup, $curs_schema);
    if (keys %genes) {
      $ret{genes} = \%genes;
    }

    my %alleles = _get_alleles($config, $curs_schema);
    if (keys %alleles) {
      $ret{alleles} = \%alleles;
    }

    my %genotypes = _get_genotypes($config, $curs_schema);

    if (keys %genotypes) {
      $ret{genotypes} = \%genotypes;
    }

    my %metagenotypes = _get_metagenotypes($config, $curs_schema);

    if (keys %metagenotypes) {
      $ret{metagenotypes} = \%metagenotypes;
    }

  }

  $curs_schema->disconnect();

  return \%ret;
}

1;
