package Canto::Chado::SubsetProcess;

=head1 NAME

Canto::Chado::SubsetProcess - Store subset data in the DB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Chado::SubsetProcess

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;

=head2 add_to_subset

 Usage   : $self->add_to_subset($subset_data, 'subset_name', 'is_a', \@subset_ids);
 Function: Add a new subset to $subset_data
 Args    : $subset_data - returned by get_subset_data()
           $subset_name
           $subset_relation - the relation the connects the subset
           $subset_ids - a array ref
 Return  : None

=cut

sub add_to_subset
{
  my $self = shift;

  my $subset_data = shift;
  my $subset_name = shift;
  my $subset_relation = shift;
  my $subset_ids = shift;

  if (!defined $subset_ids) {
    croak "no subset_ids passed to add_to_subset()";
  }

  for my $subset_id (@$subset_ids) {
    $subset_data->{$subset_id}{$subset_name}{$subset_relation} = 1;
  }
}


=head2 get_empty_subset_data

 Usage   : $subset_process->process_subset_data($track_schema, $subset_data);
 Function: Return an empty $subset_data structure

=cut

sub get_empty_subset_data
{
  return {};
}


=head2 process_subset_data

 Usage   : my $subset_data = $extension_process->get_subset_data();
           my $subset_process = Canto::Chado::SubsetProcess->new();
           $subset_process->process_subset_data($track_schema, $subset_data);
 Function: Use the results of get_subset_data() to add a canto_subset
           cvtermprop for each config file term it's a child of.  For
           more details see:
           https://github.com/pombase/canto/wiki/AnnotationExtensionConfig
 Args    : $track_schema - the database to load
           $subset_data - A map returned by subset_data()
 Return  : None - dies on failure

=cut

sub process_subset_data
{
  my $self = shift;
  my $schema = shift;
  my $subset_data = shift;

  my %db_names = ();

  map {
    if (/(\w+):/) {
      $db_names{$1} = 1;
    }
  } keys %$subset_data;

  my @db_names = keys %db_names;

  my $cvterm_rs =
    $schema->resultset('Cvterm')->search({
      'db.name' => { -in => \@db_names },
    }, {
      join => { dbxref => 'db' },
      prefetch => { dbxref => 'db' }
    });

  my $canto_subset_term =
    $schema->resultset('Cvterm')->find({ name => 'canto_subset',
                                         'cv.name' => 'cvterm_property_type' },
                                       {
                                         join => 'cv' });

  while (defined (my $cvterm = $cvterm_rs->next())) {
    my $db_accession = $cvterm->db_accession();

    my $prop_rs =
      $cvterm->cvtermprop_cvterms()
      ->search({
        type_id => $canto_subset_term->cvterm_id(),
      });

    $prop_rs->delete();

    my $subset_ids = $subset_data->{$db_accession};

    if ($subset_ids) {
      my @subset_ids_to_store = sort keys %{$subset_ids};

      my $rank = 0;

      while (@subset_ids_to_store) {
        my $subset_id = shift @subset_ids_to_store;

        my @rels = keys %{$subset_ids->{$subset_id}};

        for my $rel (@rels) {
          $schema->resultset('Cvtermprop')->create({
            cvterm_id => $cvterm->cvterm_id(),
            type_id => $canto_subset_term->cvterm_id(),
            value => "$rel($subset_id)",
            rank => $rank,
          });

          $rank++;
        }
      }
    }
  }
}

1;
