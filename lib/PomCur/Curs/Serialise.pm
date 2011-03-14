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

sub _get_genes
{
  {}
}

sub _get_organisms
{
  {}
}

sub _get_pubs
{
  {}
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
    pubs => _get_pubs($schema)
  };
}

1;
