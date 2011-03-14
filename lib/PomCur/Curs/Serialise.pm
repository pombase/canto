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

sub _get_metadata
{
  my $schema = shift;

  my @results = $schema->resultset('Metadata')->all();

  return [map { { $_->key(), $_->value() } } @results];
}

sub _get_annotations
{
  my $schema = shift;
  my $gene = shift;

  my $rs = $gene->annotations();
  my @ret = ();

  while (defined (my $annotation = $rs->next())) {
    my %extra_data = %{$annotation->data()};

    push @ret, {
      status => $annotation->status(),
      publication => $annotation->pub->uniquename(),
      type => $annotation->type(),
      creation_date => $annotation->creation_date(),
      %extra_data,
    };
  }

  return \@ret;
}

sub _get_genes
{
  my $schema = shift;

  my $rs = $schema->resultset('Gene');
  my @ret = ();

  while (defined (my $gene = $rs->next())) {
    push @ret, {
      primary_identifier => $gene->primary_identifier(),
      primary_name => $gene->primary_name(),
      product => $gene->product(),
      organism => $gene->organism()->full_name(),
      annotations => _get_annotations($schema, $gene),
    };
  }

  return \@ret;
}

sub _get_organisms
{
  my $schema = shift;

  my $rs = $schema->resultset('Organism');
  my @ret = ();

  while (defined (my $organism = $rs->next())) {
    push @ret, {
      full_name => $organism->full_name(),
      taxonid => $organism->taxonid(),
    };
  }

  return \@ret;
}

sub _get_pubs
{
  my $schema = shift;

  my $rs = $schema->resultset('Pub');
  my @ret = ();

  while (defined (my $pub = $rs->next())) {
    push @ret, {
      uniquename => $pub->uniquename(),
      title => $pub->title(),
      abstract => $pub->abstract(),
    };
  }

  return \@ret;
}

=head2 json

 Usage   : my $ser = PomCur::Curs::Serialise::json
 Function: Return a JSON representation of the given CursDB
 Args    : $schema - the CursDB
 Returns : A JSON string

=cut
sub json
{
  my $schema = shift;

  my $encoder = JSON->new()->utf8()->pretty(1);

  return $encoder->encode(perl($schema));
}

sub perl
{
  my $schema = shift;

  return {
    metadata => _get_metadata($schema),
    genes => _get_genes($schema),
    organisms => _get_organisms($schema),
    publications => _get_pubs($schema)
  };
}

1;
