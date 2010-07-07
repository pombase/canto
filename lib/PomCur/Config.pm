package PomCur::Config;

=head1 NAME

PomCur::Config - Configuration information for PomCur Perl code

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Config

You can also look for information at:

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;

use Params::Validate qw(:all);
use YAML qw(LoadFile);
use Carp;

use v5.005;

use vars qw($VERSION);

$VERSION = '0.01';

=head2 new

 Usage   : my $config = PomCur::Config->new($file_name);
 Function: Create a new Config object from the file.

=cut
sub new
{
  my $class = shift;
  my $config_file_name = shift;

  my $self = LoadFile($config_file_name);

  bless $self, $class;

  $self->setup();

  return $self;
}

=head2 setup

 Usage   : $config->setup();
 Function: perform initialisation for this object

=cut
sub setup
{
  my $self = shift;
}
1;
