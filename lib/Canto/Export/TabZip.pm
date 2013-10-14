package Canto::Export::TabZip;

=head1 NAME

Canto::Export::TabZip - Export the annotations from the sessions in
                         tab-delimited files wrapped up in Zip format

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Export::TabZip

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;

use Canto::Track::Serialise;

with 'Canto::Role::Configurable';
with 'Canto::Role::Exporter';
with 'Canto::Role::GAFFormatter';

sub export
{
  my $self = shift;

  my $config = $self->config();
  my $curs_resultset = $self->parsed_options()->{curs_resultset};

  return $self->get_all_curs_annotation_zip($config, $curs_resultset);
}

1;
