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

use PomCur::Track::LoadUtil;

has 'schema' => (
  is => 'ro',
  isa => 'PomCur::TrackDB'
);

has 'load_util' => (
  is => 'ro',
  lazy => 1,
  builder => '_build_load_util'
);

sub _build_load_util
{
  my $self = shift;

  return PomCur::Track::LoadUtil->new(schema => $self->schema());
}

sub _add_to_index
{
  my $index = shift;
  my $cvterm = shift;

  my $doc = $index->new_doc;

  $doc->set_value(ontid => $cvterm->db_accession());
  $doc->set_value(name => $cvterm->name());

  $index->add_doc($doc);
}

=head2 load

 Usage   : my $ont_load = PomCur::Track::OntLoad->new(schema => $schema);
           $ont_load->load($file_name);
 Function: Load the contents an OBO file into the schema
 Args    : $file_name - an obo format file
           $index - the index to add the terms to
 Returns : Nothing

=cut
sub load
{
  my $self = shift;
  my $file_name = shift;
  my $index = shift;

  my $schema = $self->schema();
  my $guard = $schema->txn_scope_guard;

  my $load_util = $self->load_util();

  my $parser = new GO::Parser({handler=>'obj'});

  $parser->parse($file_name);

  my $graph = $parser->handler->graph;

  my %cvterms = ();

  my $store_term_handler =
    sub {
      my $ni = shift;
      my $term = $ni->term;

      my $cv_name = $term->namespace();

      if (!$term->is_relationship_type()) {
        my $cvterm = $load_util->get_cvterm(cv_name => $cv_name,
                                            term_name => $term->name(),
                                            ontologyid => $term->acc(),
                                            definition => $term->definition());

        $cvterms{$term->acc()} = $cvterm;

        _add_to_index($index, $cvterm);
      }
    };

  $graph->iterate($store_term_handler);

  my $rels = $graph->get_all_relationships();

  for my $rel (@$rels) {
    my $subject_term_acc = $rel->subject_acc();
    my $object_term_acc = $rel->object_acc();

    # don't try to load the relationship relations
    next unless $subject_term_acc =~ /:/;

    my $rel_type = $rel->type();
    my $rel_type_ontid = "OBO_REL:$rel_type";

    my $subject_cvterm = $cvterms{$subject_term_acc};
    my $object_cvterm = $cvterms{$object_term_acc};
    my $rel_type_cvterm = $load_util->get_cvterm(cv_name => 'relationship_type',
                                                 term_name => $rel_type,
                                                 ontologyid => $rel_type_ontid);

    $schema->create_with_type('CvtermRelationship',
                              {
                                subject => $subject_cvterm,
                                object => $object_cvterm,
                                type => $rel_type_cvterm
                              });
  }

  $guard->commit();
}

1;
