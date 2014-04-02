package Canto::Curs::ServiceUtils;

=head1 NAME

Canto::Curs::ServiceUtils - Helper functions for returning lists of data to the
                            browser.

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::ServiceUtils

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Moose;

use JSON;

has curs_schema => (is => 'ro', isa => 'Canto::CursDB');

my %list_for_service_subs =
  (
    genotype =>
      sub {
        my $self = shift;

        my $curs_schema = $self->curs_schema();

        my $genotype_rs = $curs_schema->resultset('Genotype');

        my @res = map {
          {
            name => $_->name(),
          }
        } $genotype_rs->all();
      },
  );

=head2 list_for_service

 Usage   : my @result = $service_utils->list_for_service('genotype');
 Function: Return a summary list of the given curs data for sending as JSON to
           the browser.
 Args    : $type - the data type: eg. "genotype"
 Return  : a list of hash refs summarising a type.  Example for genotype:
           [ { name => 'h+ SPCC63.05-unk ssm4delta' }, { ... }, ... ]

=cut

sub list_for_service
{
  my $self = shift;

  my $type = shift;

  my $proc = $list_for_service_subs{$type};

  if (defined $proc) {
    return [$proc->($self)];
  } else {
    die "unknown list type: $type\n";
  }
}

1;
