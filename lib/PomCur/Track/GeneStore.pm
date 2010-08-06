package PomCur::Track::GeneStore;

=head1 NAME

PomCur::Track::GeneStore - A GeneStore that gets it's data from the TrackDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::GeneStore

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

with 'PomCur::GeneStore';
with 'PomCur::Track::TrackStore';

sub lookup
{
  my $self = shift;
  my $search_terms_ref = shift;
  my $options = shift;

  my @search_terms = @{$search_terms_ref};

  my $gene_rs = $self->schema()->resultset('Gene');
  my $rs = $gene_rs->search({
    primary_identifier => {
      -in => [@search_terms],
    }});

  $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

  my @return_array = $rs->all();

  return @return_array;
}

1;
