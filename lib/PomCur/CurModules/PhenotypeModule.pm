package PomCur::CurModules::PhenotypeModule;

=head1 NAME

PomCur::CurModules::PhenotypeModule - Implementation class for phenotype annotation

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::CurModules::PhenotypeModule

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

with 'PomCur::CurModule';

=head2 annotation_count

 Usage   : my ($old, $new) = $mod->annotation_count();
 Function: returns the number of annotations made before this curs started and
           the number of new annotations

=cut
sub annotation_count
{
  my $existing_count = 0;

  return ($existing_count, 0);
}

1;
