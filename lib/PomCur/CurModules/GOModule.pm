package PomCur::CurModules::GOModule;

=head1 NAME

PomCur::CurModules::GOModule - Implementation class for GO annotation

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::CurModules::GOModule

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

has 'ontologies' => (
  is => 'ro',
  isa => 'ArrayRef[Str]',
);

has 'go_lookup' => (
  is => 'ro',
  lazy_build => 1,
  init_arg => undef,
);

has 'annotation_lookup' => (
  is => 'ro',
  lazy_build => 1,
  init_arg => undef,
);

sub _build_go_annotation_lookup
{
  my $self = shift;

  my $config = $self->config();
  my $go_annotation_lookup =
    $config->{implementation_classes}->{go_annotation_lookup};

  die "GOT HERE!";

  return $go_annotation_lookup->new();
}

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
