package PomCur::Curs::Role::GeneResultSet;

=head1 NAME

PomCur::Curs::Role::GeneResultSet - Code for creating ResultSets of
                                    Genes in a CursDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Curs::Role::GeneResultSet

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose::Role;

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
    # special case, order by primary_name unless it's null, then use
    # primary_identifier
    $order_by =
      "case when primary_name is null then 'zzz' || primary_identifier " .
      "else primary_name end";
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
