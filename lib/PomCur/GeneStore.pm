package PomCur::GeneStore;

=head1 NAME

PomCur::GeneStore - A role describing gene lookup services

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::GeneStore

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose::Role;

with 'PomCur::Configurable';

=head2

 Usage     : my @results = lookup(\@search_terms, { lookup_type => 'name,identifier' });
 Function  : look up information about genes
 Returns   : an array: ({ primary_identifier => 'spbc...', name => 'cdc11',
                          chromosome => 'chr1', length => ..., ....},
                        { primary_identifier => ... })
 Args      : $search_terms - an array references of identifiers to search for,
                             genes that match of the terms will be returned
           : $options - a hash ref of options.

=cut
requires 'lookup';

1;
