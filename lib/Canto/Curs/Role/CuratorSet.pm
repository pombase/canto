package Canto::Curs::Role::CuratorSet;

=head1 NAME

Canto::Curs::Role::CuratorSet - Role for updating the curator details in an
                                Annotation

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::Role::CuratorSet

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose::Role;

use Canto::Curs::State qw(APPROVAL_IN_PROGRESS);

requires 'get_metadata';
requires 'state';

=head2 set_annotation_curator

 Usage   : $self->set_annotation_curator();
 Function: Set the "curator" field of the data blob of an Annotation to be the
           current curator.
           The current curator will be the reviewer if approval is in progress.

 Args    : $annotation - the Annotation to update
 Return  : None

=cut

sub set_annotation_curator
{
  my $self = shift;
  my $annotation = shift;

  my $schema = $annotation->result_source()->schema();

  my $curs_key = $self->get_metadata($schema, 'curs_key');

  my $curator_email;
  my $curator_name;
  my $curator_known_as;
  my $accepted_date;
  my $community_curated;
  my ($creation_date, $curs_curator_id, $curator_orcid);

  my ($state, $submitter, $gene_count) = $self->state()->get_state($schema);

  if ($state eq APPROVAL_IN_PROGRESS) {
    $curator_name = $self->get_metadata($schema, 'approver_name');
    $curator_email = $self->get_metadata($schema, 'approver_email');
  } else {
    ($curator_email, $curator_name, $curator_known_as,
     $accepted_date, $community_curated,
     $creation_date, $curs_curator_id, $curator_orcid) =
      $self->state()->curator_manager()->current_curator($curs_key);
  }

  my $data = $annotation->data();
  $data->{curator} = {
    email => $curator_email,
    name => $curator_name,
    community_curated => $community_curated // 0,
    curator_orcid => $curator_orcid,
  };

  $annotation->data($data);
  $annotation->update();
}

1;
