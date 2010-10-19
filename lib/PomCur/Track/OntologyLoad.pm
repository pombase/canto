package PomCur::Track::OntologyLoad;

=head1 NAME

PomCur::Track::OntologyLoad - Code for loading ontology information into a
                              TrackDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::OntologyLoad

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

use GO::Parser;

has 'schema' => (
  is => 'ro',
  isa => 'PomCur::TrackDB'
);

has 'load_util' => (
  is => 'ro',
  lazy => 1,
  builder => '_build_load_util'
);

=head2 load

 Usage   : my $ont_load = PomCur::Track::OntLoad->new(schema => $schema);
           $ont_load->load($file_name);
 Function: Load the contents an OBO file into the schema
 Args    : $file_name - an obo format file
 Returns : Nothing

=cut
sub load
{
  my $self = shift;
  my $file_name = shift;

  my $schema = $self->schema();
  my $guard = $schema->txn_scope_guard;

  my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);

  my $parser = new GO::Parser({handler=>'obj'});

  $parser->parse($file_name);

  my $graph = $parser->handler->graph;

  my $store_term_handler =
    sub {
      my $ni = shift;
      my $term = $ni->term;

      if (!$term->is_relationship_type()) {
        my $term = $load_util->get_cvterm(cv_name => cv_name,
                                          term_name => $term->name(),
                                          ontologyid => $term->id(),
                                          definition => $term->definition());

        $cvterms{$term->id()} = $term;
      }
    };

  $graph->iterate($store_term_handler);

  my $rels = $graph->get_all_relationships();

  for my $rel (@$rels) {
    my $subject_term = $rel->subject();
    my $object_term = $rel->object();

    my $subject_cvterm = $cvterms{$subject_term->id()};
    my $object_cvterm = $cvterms{$object_term->id()};
    my $rel_type_cvterm = ...;

    $schema->create_with_type('CvtermRelationship',
                              {
                                subject => $subject_cvterm,
                                object => $object_cvterm,
                                type = $rel_type_cvterm
                              });
  }

  $guard->commit();
}

1;
