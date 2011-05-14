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

use Package::Alias UniProtUtil => 'PomCur::UniProt::UniProtUtil';

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
  my $search_terms_ref = shift;

  my @results = UniProtUtil::retrieve_entries($self->config(),
                                              $search_terms_ref);

  my @found_genes = map


  return { found => \@found_genes,
           missing => \@missing_genes };
}

1;
