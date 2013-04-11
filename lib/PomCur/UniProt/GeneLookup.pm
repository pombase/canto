package PomCur::UniProt::GeneLookup;

=head1 NAME

PomCur::UniProt::GeneLookup - Look up genes/proteins using the UniProt web
                              service

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::UniProt::GeneLookup

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

with 'PomCur::Role::Configurable';
with 'PomCur::Role::GeneLookupCache';

use Package::Alias UniProtUtil => 'PomCur::UniProt::UniProtUtil';
use Clone qw(clone);

=head2 lookup

 Usage   : my $gene_lookup = PomCur::UniProt::get_adaptor($config, 'gene');
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
              missing => ['test'] }

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
      $options->{search_organism}->{genus}, " ",
      $options->{search_organism}->{species}, qq(" for UniProt gene lookups);
  }

  my $search_terms_ref = shift;

  my @results = UniProtUtil::retrieve_entries($self->config(),
                                              $search_terms_ref);

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
