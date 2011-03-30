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

use Text::Similarity::Overlaps;

use PomCur::Track::OntologyIndex;

with 'PomCur::Role::Configurable';
with 'PomCur::Track::TrackLookup';

sub _get_score
{
  my $tso = shift;
  my $search_string = shift;
  my $name = shift;

  $name =~ s/\W+/ /g;

  return $tso->getSimilarityStrings($search_string, $name);
}

sub _make_term_hash
{
  my $search_string = shift;
  my $cvterm = shift;
  my $include_definition = shift;
  my $include_children = shift;
  my $matching_synonym = shift;

  my $cv = $cvterm->cv();

  my %term_hash = ();

  $term_hash{id} = $cvterm->db_accession();
  $term_hash{name} = $cvterm->name();
  $term_hash{matching_synonym} = $matching_synonym;

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
      ->search_related('subject', {}, { order_by => 'name' })->all();

    for my $child_cvterm (@child_cvterms) {
      if ($child_cvterm->cv()->name() eq $cv->name()) {
        push @{$term_hash{children}}, {
          _make_term_hash($search_string, $child_cvterm, 0, 0)
        };
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
               matching_synonym => '...',
               children => [ { id => '...' }, { id => '...' }, ... ] } ]

           Note: if the search_string matches a synonym more exactly
           than it matches the cvterm name, the matching_synonym field
           is name that synonym, otherwise matching_synonym won't be
           returned in the hash

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
  my $tso = Text::Similarity::Overlaps->new();
  my $fudge_factor = 1.05;

  my $num_hits = $hits->length();

  my @limited_hits = ();

  for (my $i = 0; $i < $max_results && $i < $num_hits; $i++) {
    my $doc = $hits->doc($i);
    my $cvterm_id = $doc->get('cvterm_id');
    my $cvterm = $schema->find_with_type('Cvterm', $cvterm_id);

    # the $fudge_factor is to try to make sure that the cvterm name is nudged
    # ahead if there is need for a tie-break
    my $name_match_score =
      _get_score($tso, $search_string, $cvterm->name()) * $fudge_factor;

    my $max_score = $name_match_score;
    my $matching_synonym = undef;

    for my $synonym ($cvterm->synonyms()) {
      my $synonym_name = $synonym->synonym();
      my $synonym_score = _get_score($tso, $search_string, $synonym_name);

      if ($synonym_score > $max_score) {
        $max_score = $synonym_score;
        $matching_synonym = $synonym_name;
      }
    }

    push @limited_hits, { doc => $doc, score => $hits->score($i),
                          cvterm => $cvterm,
                          cvterm_name => $cvterm->name(),
                          matching_synonym => $matching_synonym };
  }

  # sort by score, then matching_synonym length or cvterm name length
  @limited_hits = sort {
    my $score_cmp = $b->{score} <=> $a->{score};

    if ($score_cmp == 0) {
      my $a_length;
      if ($a->{matching_synonym}) {
        $a_length = length $a->{matching_synonym};
      } else {
        $a_length = length $a->{cvterm_name};
      }
      my $b_length;
      if ($b->{matching_synonym}) {
        $b_length = length $b->{matching_synonym};
      } else {
        $b_length = length $b->{cvterm_name};
      }
      $a_length <=> $b_length;
    } else {
      $score_cmp;
    }
  } @limited_hits;

  for my $hit_hash (@limited_hits) {
    my $doc = $hit_hash->{doc};
    my $name = $doc->get('name');
    my $ontid = $doc->get('ontid');
    my $matching_synonym = $hit_hash->{matching_synonym};
    my $cvterm = $hit_hash->{cvterm};

    my %term_hash =
      _make_term_hash($search_string, $cvterm,
                      $include_definition, $include_children,
                      $matching_synonym);

    push @ret_list, \%term_hash;
  }

  return \@ret_list;
}

1;
