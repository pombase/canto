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

use JSON;
use Clone qw(clone);
use Data::Rmap ':all';

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
  my $track_schema = shift;
  my $curs_schema = shift;

  confess() unless defined $curs_schema;

  my @results = $curs_schema->resultset('Metadata')->all();

  my %ret = map {
    my $key = $_->key();
    $key = "canto_session" if $key eq "curs_key";

    ($key, _get_metadata_value($curs_schema, $_->key(), $_->value() ))
  } @results;

  my $cursprops_rs =
    $track_schema->resultset('Curs')->find({ curs_key => $ret{canto_session} })
                 ->cursprops();

  while (defined (my $prop = $cursprops_rs->next())) {
    $ret{$prop->type()->name()} = $prop->value();
  }

  return \%ret;
}

sub _get_annotations
{
  my $config = shift;
  my $track_schema = shift;
  my $schema = shift;

  die "no schema" unless $schema;

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

            $interacting_gene->organism()->full_name() . ' ' .
              $_->{primary_identifier};
          } @{$extra_data{interacting_genes}}
        ]
    }

    my $term_ontid = delete $extra_data{term_ontid};
    if ($term_ontid) {
      $extra_data{term} = $term_ontid;
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
        my $metadata = _get_metadata($track_schema, $schema);
        die "community_curated not set for annotation ",
          $annotation->annotation_id(), " in session ",
          $metadata->{curs_key};
      }
    } else {
      my $metadata = _get_metadata($track_schema, $schema);
      die "community_curated not set for annotation ",
        $annotation->annotation_id(), " in session ",
        $metadata->{curs_key};
    }

    my $gene = _get_annotation_gene($schema, $annotation);
    my $genotype = _get_annotation_genotype($schema, $annotation);

   if ($gene) {
      $data{gene} = $gene;
    }
    if ($genotype) {
      $data{genotype} = $genotype;
    }

    rmap_hash {
      my $current = $_;
      if (exists $current->{email}) {
        # this is a curator section - don't modify
        cut();
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

    push @ret, \%data;
  }

  return \@ret;
}

sub _get_annotation_gene
{
  my $schema = shift;
  my $annotation = shift;

  my $rs = $annotation->genes();
  my @ret = ();

  while (defined (my $gene = $rs->next())) {
    my $organism_full_name = $gene->organism()->full_name();
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
  my $schema = shift;

  my $rs = $schema->resultset('Gene');
  my %ret = ();

  while (defined (my $gene = $rs->next())) {
    my $organism_full_name = $gene->organism()->full_name();
    my %gene_data = (
      organism => $organism_full_name,
      uniquename => $gene->primary_identifier(),
    );
    my $gene_key =
      $organism_full_name . ' ' . $gene->primary_identifier();
    $ret{$gene_key} = { %gene_data };
  }

  return %ret;
}

sub _get_genotype_alleles
{
  my $config = shift;
  my $schema = shift;
  my $genotype = shift;

  my $rs = $genotype->alleles();

  my @ret = ();

  while (defined (my $allele = $rs->next())) {
    my $gene = $allele->gene();
    my $organism_full_name = $gene->organism()->full_name();

    if (!defined $allele->primary_identifier()) {
      warn "undefined primary_identifier: ", $allele->name(), "\n";
    }

    my %ret_hash = (
      id => "$organism_full_name " . $allele->primary_identifier(),
    );

    if ($allele->expression()) {
      $ret_hash{expression} = $allele->expression();
    }

    push @ret, \%ret_hash;
  }

  return @ret;
}

sub _get_alleles
{
  my $config = shift;
  my $schema = shift;

  my $rs = $schema->resultset('Allele');

  my %ret = ();

  while (defined (my $allele = $rs->next())) {
    my $gene = $allele->gene();
    my $organism_full_name = $gene->organism()->full_name();

    my $key = "$organism_full_name " . $allele->primary_identifier();
    my $gene_key = "$organism_full_name " . $gene->primary_identifier();

    my $export_type =
      $config->{allele_types}->{$allele->type()}->{export_type};

    if (!defined $export_type) {
      croak "can't find the export/database type for allele: ",
        ($allele->name() // 'noname'), "(", ($allele->description() // 'unknown'),
        ") of gene: ", $gene->primary_identifier(), '  type: ', $allele->type();
    }

    my %allele_data = (
      allele_type => $export_type,
      gene => $gene_key,
    );
    if (defined $allele->primary_identifier()) {
      $allele_data{primary_identifier} = $allele->primary_identifier();
    }
    if (defined $allele->description()) {
      $allele_data{description} = $allele->description();
    }
    if (defined $allele->name()) {
      $allele_data{name} = $allele->name();
    }

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

sub _get_genotypes
{
  my $config = shift;
  my $schema = shift;

  my $rs = $schema->resultset('Genotype');
  my %ret = ();

  while (defined (my $genotype = $rs->next())) {
    $ret{$genotype->identifier()} = {
      alleles => [_get_genotype_alleles($config, $schema, $genotype)]
    };

    if ($genotype->name()) {
      $ret{$genotype->identifier()}->{name} = $genotype->name(),
    }
  }

  return %ret;
}

sub _get_organisms
{
  my $schema = shift;

  my $rs = $schema->resultset('Organism');
  my %ret = ();

  while (defined (my $organism= $rs->next())) {
    $ret{$organism->taxonid()} = { full_name => $organism->full_name() };
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
        abstract => $pub->abstract(),
      };
    } else {
      $ret{$pub->uniquename()} = { };
    }
  }

  return \%ret;
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

  my $curs_schema =
    Canto::Curs::get_schema_for_key($config, $curs_key,
                                    {
                                      cache_connection => 0,
                                    });

  my %ret = (
    metadata => _get_metadata($track_schema, $curs_schema),
    annotations => _get_annotations($config, $track_schema, $curs_schema),
    organisms => _get_organisms($curs_schema, $options),
    publications => _get_pubs($curs_schema, $options)
  );

  my %genes = _get_genes($curs_schema);
  if (keys %genes) {
    $ret{genes} = \%genes;
  }

  my %alleles = _get_alleles($config, $curs_schema);
  if (keys %alleles) {
    $ret{alleles} = \%alleles;
  }

  my %genotypes = _get_genotypes($config, $curs_schema);

  if (%genotypes) {
    $ret{genotypes} = \%genotypes;
  }

  return \%ret;
}

1;
