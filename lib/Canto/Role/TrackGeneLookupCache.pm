package Canto::Role::TrackGeneLookupCache;

=head1 NAME

Canto::Role::TrackGeneLookupCache - The Role will wrap a GeneLookup adaptor and then cache
  the lookup results in the TrackDB.  Used by UniProt::GeneLookup

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Role::TrackGeneLookupCache

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2018 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose::Role;

use Canto::Track::LoadUtil;
use Canto::Track::GeneLoad;

has track_gene_lookup => (is => 'ro', init_arg => undef, lazy_build => 1);

requires "schema";

sub _build_track_gene_lookup
{
  my $self = shift;

  return Canto::Track::GeneLookup->new(config => $self->config());
}

around 'lookup' => sub {
  my $orig = shift;
  my $self = shift;

  my $schema = $self->schema();

  my $track_result = $self->track_gene_lookup()->lookup(@_);

  my $track_found = $track_result->{found};
  my $track_missing = $track_result->{missing};

  if (scalar @{$track_missing} == 0) {
    return $track_result;
  }

  my $uniprot_result = $self->$orig($track_missing);

  my $load_util = Canto::Track::LoadUtil->new(schema => $schema);

  map {
    my $scientific_name = $_->{organism_full_name};
    my $organism_common_name = $_->{organism_common_name};
    my $taxonid = $_->{organism_taxonid};
    my $organism = $load_util->get_organism($scientific_name, $taxonid,
                                            $organism_common_name);

    # this is to handle the case where we don't find the gene in the TrackDB when
    # searching using the primary_name but we do find it in UniProt because the name
    # has changed:
    my $gene = $schema->resultset('Gene')
      ->find({ primary_identifier => $_->{primary_identifier} });
    if ($gene) {
      $gene->genesynonyms()->delete();
      $gene->delete();
    }

    my $gene_load = Canto::Track::GeneLoad->new(organism => $organism, schema => $schema);

    $gene_load->create_gene($_->{primary_identifier}, $_->{primary_name},
                            $_->{synonyms}, $_->{product});
  } @{$uniprot_result->{found}};

  my %return_result = (
    found => [@$track_found, @{$uniprot_result->{found}}],
    missing => $uniprot_result->{missing},
  );

  return \%return_result;
};

1;
