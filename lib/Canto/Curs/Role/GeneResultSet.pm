package Canto::Curs::Role::GeneResultSet;

=head1 NAME

Canto::Curs::Role::GeneResultSet - Code for creating ResultSets of
                                    Genes in a CursDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::Role::GeneResultSet

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Moose::Role;
use Carp;

=head2 get_ordered_gene_rs

 Usage   : my $gene_rs = get_ordered_gene_rs($schema, $order_by_field);
 Function: Return an ordered resultset of genes
 Args    : $schema - the CursDB schema
           $order_by_field - the field to order by, defaults to gene_id
 Returns : a ResultSet

=cut
sub get_ordered_gene_rs
{
  my $self = shift;
  my $schema = shift;

  my $order_by_field = shift // 'gene_id';
  my $order_by;

  if ($order_by_field eq 'primary_name') {
    croak "can't order by primary_name - column doesn't exist";
  } else {
    $order_by = {
      -asc => $order_by_field
    }
  }

  return $schema->resultset('Gene')->search({},
                                            {
                                              order_by => $order_by
                                            });
}

1;
