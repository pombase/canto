package PomCur::GeneStore.pm

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

use strict;
use warnings;
use Carp;

use Moose::Role;

=head2

 Returns   : an array: [{ identifier => 'spbc...', name => 'cdc11',
                          chromosome => 'chr1', length => ..., ....},
                        { identifier => ... }]

=cut
method gene_lookup(\@search_terms, { lookup_type => 'name,identifier'|'all' });

1;
