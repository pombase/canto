package Canto::Track::StrainLookup;

=head1 NAME

Canto::Track::StrainLookup - an adaptor for looking up the possible
                             strains for an organism

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::StrainLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;

with 'Canto::Role::Configurable';
with 'Canto::Track::TrackAdaptor';

=head2 lookup()

 Usage   : my $strain_lookup = Canto::Track::get_adaptor($config, 'strain');
           my @strains = $strain_lookup->lookup($organism_taxonid);
 Function: Lookup the strains for an organism in TrackDB
 Args    : $organism_taxonid - The NCBI taxon ID of the organism to retrieve the
                               strains for
 Return  : A list of strains in the format:
           ( { name => 'string name one, },
             { name => 'string name two, }, )

=cut

sub lookup
{
  my $self = shift;
  my $taxonid = shift;

  return ();
}

1;
