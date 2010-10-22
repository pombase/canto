package PomCur::Track::OntologyIndex;

=head1 NAME

PomCur::Track::OntologyIndex -

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::OntologyIndex

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

use File::Path qw(remove_tree);

with 'PomCur::Configurable';

=head2 initialise_index

 Usage   : $ont_index->initialise_index();
 Function: Create a new empty index using the path in the configuration
 Args    : None
 Returns : Nothing

=cut
sub initialise_index
{
  my $self = shift;

  my $config = $self->config();
  my $analyzer = KinoSearch::Analysis::PolyAnalyzer->new(language => 'en');

  my $ontology_index_path = $config->data_dir_path('ontology_index_file');

  remove_tree($ontology_index_path, { error => \my $rm_err } );

  if (@$rm_err) {
    for my $diag (@$rm_err) {
      my ($file, $message) = %$diag;
      warn "error: $message\n";
    }
    exit (1);
  }

  my $invindexer = KinoSearch::InvIndexer->new(
    invindex => $ontology_index_path,
    create   => 1,
    analyzer => $analyzer,
  );

  $invindexer->spec_field(
    name  => 'name',
#    boost => 3,
  );
  $invindexer->spec_field(
    name  => 'ontid',
  );
  $invindexer->spec_field(
    name  => 'cvname',
  );

  $self->{_index} = $invindexer;
}

=head2 add_to_index

 Usage   : $ont_index->add_to_index($cvterm);
 Function: Add a cvterm to the index
 Args    : $cvterm - the Cvterm object
 Returns : Nothing

=cut
sub add_to_index
{
  my $self = shift;
  my $cvterm = shift;

  my $index = $self->{_index};

  my $doc = $index->new_doc();

  $doc->set_value(ontid => $cvterm->db_accession());
  $doc->set_value(name => $cvterm->name());
  $doc->set_value(cvname => $cvterm->cv()->name());

  $index->add_doc($doc);
}

=head2 finish_index

 Usage   : $ont_index->finish_index();
 Function: Finish creating an index
 Args    : None
 Returns : Nothing

=cut
sub finish_index
{
  my $self = shift;

  $self->{_index}->finish();
}

1;
