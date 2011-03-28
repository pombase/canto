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

=head2 load

 Usage   : my $ont_load = PomCur::Track::OntLoad->new(schema => $schema);
           $ont_load->load($file_name);
 Function: Load the contents an OBO file into the schema
 Args    : $file_name - an obo format file
           $index - the index to add the terms to (optional)
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
  my $comment_cvterm = $schema->find_with_type('Cvterm', { name => 'comment' });
  my $parser = GO::Parser->new({ handler=>'obj' });

  $parser->parse($file_name);

  my $graph = $parser->handler->graph;
  my %cvterms = ();

  my @synonym_types_to_load = qw(exact);
  my %synonym_type_ids = ();

  for my $synonym_type (@synonym_types_to_load) {
    $synonym_type_ids{$synonym_type} =
      $schema->find_with_type('Cvterm', { name => $synonym_type })->cvterm_id();
  }

  my %relationship_cvterms = ();

  my $relationship_cv =
    $schema->resultset('Cv')->find({ name => 'relationship' });
  my $isa_cvterm = undef;

  if (defined $relationship_cv) {
    $isa_cvterm =
      $schema->resultset('Cvterm')->find({ name => 'is_a',
                                           cv_id => $relationship_cv->cv_id() });

    $relationship_cvterms{is_a} = $isa_cvterm;
  }

  my $store_term_handler =
    sub {
      my $ni = shift;
      my $term = $ni->term;

      my $cv_name = $term->namespace();
      my $comment = $term->comment();
      my $synonyms = $term->synonyms_by_type('exact');

      my $xrefs = $term->dbxref_list();

      for my $xref (@$xrefs) {
        my $x_db_name = $xref->xref_dbname();
        my $x_acc = $xref->xref_key();

        my $x_db = $schema->resultset('Db')->find({ name => $x_db_name });

        if (defined $x_db) {
          my $x_dbxref =
            $schema->resultset('Dbxref')->find({ accession => $x_acc,
                                                 db_id => $x_db->db_id() });

          if (defined $x_dbxref) {
            # no need to add it as it's already there, loaded from another
            # ontology
            if ($term->is_relationship_type()) {
              my $x_dbxref_id = $x_dbxref->dbxref_id();
              my $cvterm_rs = $schema->resultset('Cvterm');
              my ($cvterm) = $cvterm_rs->search({dbxref_id => $x_dbxref_id});
              $relationship_cvterms{$term->name()} = $cvterm;
            }

            return;
          }
        }
      }

      if (!$term->is_obsolete()) {
        my $cvterm = $load_util->get_cvterm(cv_name => $cv_name,
                                            term_name => $term->name(),
                                            ontologyid => $term->acc(),
                                            definition => $term->definition(),
                                            is_relationshiptype =>
                                              $term->is_relationship_type());

        if ($term->is_relationship_type()) {
          $relationship_cvterms{$term->name()} = $cvterm;
        }

        my $cvterm_id = $cvterm->cvterm_id();

        if (defined $comment) {
          my $cvtermprop =
            $schema->create_with_type('Cvtermprop',
                                      {
                                        cvterm_id => $cvterm_id,
                                        type_id =>
                                          $comment_cvterm->cvterm_id(),
                                        value => $comment,
                                        rank => 0,
                                      });
        }

        if (@$synonyms) {
          for my $synonym (@$synonyms) {
            $schema->create_with_type('Cvtermsynonym',
                                      {
                                        cvterm_id => $cvterm->cvterm_id(),
                                        synonym => $synonym,
                                        type_id => $synonym_type_ids{exact},
                                      });
          }
        }

        $cvterms{$term->acc()} = $cvterm;

        $index->add_to_index($cvterm) if $index;
      }
    };

  $graph->iterate($store_term_handler);

  my $rels = $graph->get_all_relationships();

  for my $rel (@$rels) {
    my $subject_term_acc = $rel->subject_acc();
    my $object_term_acc = $rel->object_acc();

    next if $rel->type() eq 'has_part' ||
      $rel->type() eq 'has_functional_parent' ||
      $rel->type() eq 'derives_from';

    my $rel_type = $rel->type();
    my $rel_type_cvterm = $relationship_cvterms{$rel_type};

    my $subject_cvterm = $cvterms{$subject_term_acc};
    my $object_cvterm = $cvterms{$object_term_acc};

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
