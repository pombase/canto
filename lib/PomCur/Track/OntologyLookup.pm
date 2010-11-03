package PomCur::Track::OntologyLookup;

=head1 NAME

PomCur::Track::OntologyLookup - Lookup/search methods for ontologies

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::GOLookup

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

use PomCur::Track::OntologyIndex;

with 'PomCur::Configurable';
with 'PomCur::Track::TrackLookup';

sub _make_term_hash
{
  my $cvterm = shift;
  my $include_definition = shift;
  my $include_children = shift;

  my $cv = $cvterm->cv();

  my %term_hash = ();

  $term_hash{id} = $cvterm->db_accession();
  $term_hash{name} = $cvterm->name();

  if ($include_definition) {
    $term_hash{definition} = $cvterm->definition();
    my $comment_prop =
      $cvterm->cvtermprop_cvterms()->search({ 'type.name' => 'comment' },
                                            {
                                              join => 'type',
                                            })->first();
    if ($comment_prop) {
      $term_hash{comment} = $comment_prop->value();
    }
  }

  if ($include_children) {
    @{$term_hash{children}} = ();

    my @child_cvterms = $cvterm->cvterm_relationship_objects()
      ->search_related('subject')->all();

    for my $child_cvterm (@child_cvterms) {
      if ($child_cvterm->cv()->name() eq $cv->name()) {
        push @{$term_hash{children}}, {_make_term_hash($child_cvterm, 0, 0)};
      }
    }
  }

  return %term_hash;
}

=head2 web_service_lookup

 Usage   : my $lookup = PomCur::Track::OntologyLookup->new(...);
           my $result =
             $lookup->web_service_lookup(search_string => $search_string,
                                         ontology_name => $ontology_name);
 Function: Return matching ontology terms
 Args    : ontology_name - the ontology to search
           search_string - the text to use when searching, if this is a ontology
                           ID (eg. "GO:0012345") return just that match
           max_results - maximum hits to return
           include_children - include data about the child terms
           include_definition - include the definition for each term
 Returns : [ { id => '...', name => '...', definition => '...',
               children => [ { id => '...' }, { id => '...' }, ... ] } ]

=cut
sub web_service_lookup
{
  my $self = shift;
  my %args = @_;

  my $ontology_name = $args{ontology_name};
  my $search_string = $args{search_string};
  my $max_results = $args{max_results} || 10;
  my $include_definition = $args{include_definition};
  my $include_children = $args{include_children};

  my $config = $self->config();
  my $ontology_index = PomCur::Track::OntologyIndex->new(config => $config);

  my $hits = $ontology_index->lookup($ontology_name, $search_string,
                                     $max_results);

  my @ret_list = ();

  my $schema = $self->schema();

  my $num_hits = $hits->length();

  for (my $i = 0; $i < $max_results && $i < $num_hits; $i++) {
    my $doc = $hits->doc($i);
    my $name = $doc->get('name');
    my $ontid = $doc->get('ontid');
    my $cvterm_id = $doc->get('cvterm_id');

    my $cvterm = $schema->find_with_type('Cvterm', $cvterm_id);

    my %term_hash =
      _make_term_hash($cvterm, $include_definition, $include_children);

    push @ret_list, \%term_hash;
  }

  return \@ret_list;
}

1;
