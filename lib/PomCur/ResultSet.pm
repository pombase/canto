package PomCur::ResultSet;

=head1 NAME

PomCur::DB::ResultSet - A PomCur specific sub class of ResultSet

=head1 SYNOPSIS

DBIx::Class v0.08010 has a problem with using relations where the relation name
doesn't match the column name, eg. having sample.organism_id as the field name
but referring to the field as "organism" ($sample->organism()).  If an object
(sample) is create without the field (organism/organism_id) then if the field
is referred to (if (defined $sample->organism()) then the Organism object is
created.   This sub-class fixes the problem by setting all fields that aren't
passed to the create() method to undef.

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SmallRNA::DBResultSet

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

use base qw/DBIx::Class::ResultSet::Data::Pageset/;

1;

