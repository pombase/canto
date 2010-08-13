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
    -or => [
      primary_identifier => {
        -in => [@search_terms],
      },
      primary_name => {
        -in => [@search_terms],
      },
    ]
   });

  $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

  my @found_genes = $rs->all();

  my %gene_ids = ();

  for my $found_gene (@found_genes) {
    my $gene_identifier = $found_gene->{primary_identifier};
    if (defined $gene_identifier) {
      $gene_ids{$gene_identifier} = 1;
    }
    my $gene_name = $found_gene->{primary_name};
    if (defined $gene_name) {
      $gene_ids{$gene_name} = 1;
    }
  }

  my @missing_genes = grep {
    !exists $gene_ids{$_}
  } @search_terms;

  return { found => \@found_genes,
           missing => \@missing_genes };
}

1;
