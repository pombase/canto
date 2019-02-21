package Canto::UniProt::GeneLookup;

=head1 NAME

Canto::UniProt::GeneLookup - Look up genes/proteins using the UniProt web
                              service

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::UniProt::GeneLookup

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

use Carp;
use Moose;

use Canto::Track::GeneLookup;

has schema => (is => 'rw', init_arg => undef, lazy_build => 1);

with 'Canto::Role::Configurable';
with 'Canto::Role::TrackGeneLookupCache';
with 'Canto::Role::GeneLookupCache';

has organism_lookup => (is => 'rw', isa => 'Canto::Track::OrganismLookup',
                        lazy_build => 1);

sub _build_organism_lookup
{
  my $self = shift;

  return Canto::Track::get_adaptor($self->config(), 'organism');
}

use Package::Alias UniProtUtil => 'Canto::UniProt::UniProtUtil';
use Clone qw(clone);

sub _get_results
{
  my $self = shift;
  my $search_terms_ref = shift;

  my @results = UniProtUtil::retrieve_entries($self->config(), $search_terms_ref);

  map {
    my $result = $_;

    my $species_taxon_id =
      $self->config()->get_species_taxon_of_strain_taxon($result->{organism_taxonid});
    if ($species_taxon_id) {
      # this gene is from a strain, swap in the species details
      # See: https://github.com/pombase/canto/issues/1611
      my $organism_lookup = $self->organism_lookup();

      my $organism_details = $organism_lookup->lookup_by_taxonid($species_taxon_id);

      $result->{organism_taxonid} = $species_taxon_id;
      $result->{organism_full_name} = $organism_details->{scientific_name};
      $result->{organism_common_name} = $organism_details->{common_name};
    }
  } @results;

  return @results;
}

sub _build_schema
{
  my $self = shift;

  my $config = $self->config();

  return Canto::TrackDB->new(config => $config);
}

=head2 lookup

 Usage   : my $gene_lookup = Canto::Track::get_adaptor($config, 'gene');
           my $results =
             $gene_lookup->lookup(['O74473', 'DPOD_YEAST', 'test')]);
 Function: Search for proteins by accession or identifier
 Args    : $search_terms_ref - an array reference containing the terms to search
                               for
 Returns : All genes that match any of the search terms exactly.  The result
           should look like this hashref:
            { found => [{
                         primary_name => 'DPOD_YEAST',
                         primary_identifier => 'P15436'
                         product => 'DNA polymerase delta catalytic subunit',
                         synonyms => ['CDC2', 'TEX1'],
                         organism_full_name => 'Saccharomyces cerevisiae',
                         organism_taxonid => 559292,
                         match_types => { primary_name => 'DPOD_YEAST',
                                        },
                        }, ... ],
              missing => ['O74473', 'test'] }

=cut
sub lookup
{
  my $self = shift;

  my $options = {};
  if (@_ == 2) {
    $options = shift;
  }
  if (exists $options->{search_organism}) {
    croak qq(can't handle search_organism option "),
      $options->{search_organism}->{scientific_name}, qq(" for UniProt gene lookups);
  }

  my $search_terms_ref = shift;

  @$search_terms_ref = map { uc } @$search_terms_ref;

  my @results = $self->_get_results($search_terms_ref);

  my %missing_search_terms = ();
  @missing_search_terms{@$search_terms_ref} = @$search_terms_ref;

  my @found_genes = map {
    my $h = clone $_;
    $h->{match_type} = { primary_identifier => $h->{primary_identifier} };
    delete $missing_search_terms{$h->{primary_name}};
    delete $missing_search_terms{$h->{primary_identifier}};
    $h
  } @results;

  my @missing_genes = (keys %missing_search_terms);

  return { found => \@found_genes,
           missing => \@missing_genes };
}

1;
