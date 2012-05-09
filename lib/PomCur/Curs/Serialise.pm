package PomCur::Curs::Serialise;

=head1 NAME

PomCur::Curs::Serialise - Code for serialising and de-serialising a CursDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Curs::Serialise

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;

use JSON;

sub _get_metadata_value
{
  my $schema = shift;
  my $key = shift;
  my $value = shift;

  if ($key eq 'curation_pub_id') {
    return $schema->find_with_type('Pub', $value)->uniquename();
  } else {
    return $value;
  }
}

sub _get_metadata
{
  my $schema = shift;

  my @results = $schema->resultset('Metadata')->all();

  return { map {
      ($_->key(), _get_metadata_value($schema, $_->key(), $_->value() ))
    } @results };
}

sub _get_annotations
{
  my $schema = shift;

  my $rs = $schema->resultset('Annotation');

  my @ret = ();

  while (defined (my $annotation = $rs->next())) {
    my %extra_data = %{$annotation->data()};

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

    my $genes = _get_genes($schema, $annotation);
    my @alleles = _get_alleles($schema, $annotation);

    if (keys %$genes) {
      $data{genes} = $genes;
    }
    if (@alleles) {
      $data{alleles} = \@alleles;
    }

    push @ret, \%data;
  }

  return \@ret;
}

sub _get_genes
{
  my $schema = shift;
  my $annotation = shift;

  my $rs = $annotation->genes();
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

  return \%ret;
}

sub _get_alleles
{
  my $schema = shift;
  my $annotation = shift;

  my $rs = $annotation->alleles();
  my @ret = ();

  while (defined (my $allele = $rs->next())) {
    my $gene = $allele->gene();
    my $organism_full_name = $gene->organism()->full_name();
    my %gene_data = (
      organism => $organism_full_name,
      uniquename => $gene->primary_identifier(),
    );
    my %allele_data = (
      type => $allele->type(),
      gene => \%gene_data,
    );
    if (defined $allele->primary_identifier()) {
      $allele_data{primary_identifier} = $allele->primary_identifier();
    }
    if (defined $allele->description()) {
      $allele_data{description} = $allele->description();
    }
    push @ret, \%allele_data;
  }

  return @ret;
}

sub _get_organisms
{
  my $schema = shift;

  my $rs = $schema->resultset('Organism');
  my %ret = ();

  while (defined (my $organism = $rs->next())) {
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
    if ($options->{dump_all}) {
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

 Usage   : my $ser = PomCur::Curs::Serialise::json($curs_schema);
 Function: Return a JSON representation of the given CursDB
 Args    : $schema - the CursDB
 Returns : A JSON string

=cut
sub json
{
  my $schema = shift;
  my $options = shift;

  my $encoder = JSON->new()->utf8()->pretty(1)->canonical(1);

  return $encoder->encode(perl($schema, $options));
}

=head2 perl

 Usage   : my $ser = PomCur::Curs::Serialise::perl($curs_schema);
 Function: Return a Perl hash representating all the data in the given CursDB
 Args    : $schema - the CursDB
           $options - export options - see documentation for
             PomCur::Track::Serialise::json()
 Returns : A Perl hashref

=cut
sub perl
{
  my $schema = shift;
  my $options = shift;

  return {
    metadata => _get_metadata($schema),
    annotations => _get_annotations($schema),
    organisms => _get_organisms($schema, $options),
    publications => _get_pubs($schema, $options)
  };
}

1;
