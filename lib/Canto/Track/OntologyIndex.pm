package Canto::Track::OntologyIndex;

=head1 NAME

Canto::Track::OntologyIndex -

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::OntologyIndex

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

use File::Path qw(remove_tree);

use Lucene;

has index_path => (is => 'rw', required => 1);
has config => (is => 'ro', required => 1);

=head2 initialise_index

 Usage   : $ont_index->initialise_index();
 Function: Create a new empty index in a temporary directory.
 Args    : None
 Returns : Nothing

=cut
sub initialise_index
{
  my $self = shift;

  $self->_remove_dir($self->_temp_index_path());

  my $init_analyzer = new Lucene::Analysis::Standard::StandardAnalyzer();
  my $store = Lucene::Store::FSDirectory->getDirectory($self->_temp_index_path(), 1);

  my $tmp_writer = new Lucene::Index::IndexWriter($store, $init_analyzer, 1);
  $tmp_writer->close;
  undef $tmp_writer;

  my $analyzer = new Lucene::Analysis::Standard::StandardAnalyzer();
  my $writer = new Lucene::Index::IndexWriter($store, $analyzer, 0);

  $self->{_index} = $writer;
}

sub _remove_dir
{
  my $self = shift;

  my $path = shift;

  remove_tree($path, { error => \my $rm_err } );

  if (@$rm_err) {
    for my $diag (@$rm_err) {
      my ($file, $message) = %$diag;
      warn "error: $message\n";
    }
    die;
  }
}

sub _temp_index_path
{
  my $self = shift;

  return $self->index_path() . ".tmp";
}

sub _get_all_names
{
  my $term_name = shift;
  my $synonym_details = shift;

  return (['name', $term_name],
          map {
            [$_->{type}, $_->{synonym}];
          } @$synonym_details);
}

sub _id_for_lucene
{
  my $id = lc shift;
  $id =~ s/:/_/g;
  $id =~ s/(.*)\((.*)\)/$1__$2/;
  return $id;
}

=head2 add_to_index

 Usage   : $ont_index->add_to_index($cvterm, \@cvterm_synonyms);
 Function: Add a cvterm to the index
 Args    : $cv_name - the CV name for this term
           $term_name - the cvterm name
           $cvterm_id - the database ID for the term
           $db_accession - the "DB_NAME:ACCESSION" string for this term
           $subset_ids - a list of any subsets that contain this term
           $synonym_details - an array of the name and type of the synonyms
                              of $cvterm
                              eg. [{ name => '...', type => '...'}, {...}]
 Returns : Nothing

=cut
sub add_to_index
{
  my $self = shift;
  my $cv_name = lc shift;
  my $term_name = shift;
  my $cvterm_id = shift;
  my $db_accession = shift;
  my $subset_ids = shift;
  my $synonym_details = shift;

  my %synonym_boosts = %{$self->config()->{load}->{ontology}->{synonym_boosts}};
  my %term_boosts = %{$self->config()->{load}->{ontology}->{term_boosts} // {}};

  $cv_name =~ s/-/_/g;

  my $writer = $self->{_index};

  my @all_name_details = _get_all_names($term_name, $synonym_details);

  my %type_counts = ();

  for my $details (@all_name_details) {
    my $type = $details->[0];
    if (exists $type_counts{$type}) {
      $type_counts{$type}++;
    } else {
      $type_counts{$type} = 1;
    }
  }

  # $text can be the name or a synonym
  for my $details (@all_name_details) {
    my $doc = Lucene::Document->new();

    my $type = $details->[0];
    my $text = $details->[1];

    my @fields = (
      Lucene::Document::Field->Text('text', $text),
      Lucene::Document::Field->Keyword(ontid => $db_accession),
      Lucene::Document::Field->Keyword(cv_name => $cv_name),
      (map {
        # change "is_a(GO:0005215)" to "is_a__GO_0005215"
        my $id_for_lucene = _id_for_lucene($_);
        Lucene::Document::Field->Keyword(subset_id => $id_for_lucene)
      } @$subset_ids),
      Lucene::Document::Field->UnIndexed(cvterm_id => $cvterm_id),
      Lucene::Document::Field->UnIndexed(term_name => $term_name),
    );

    if (exists $synonym_boosts{$type}) {
      my $factor = $type_counts{$type};
      map { $_->setBoost($synonym_boosts{$type} / $factor); } @fields;
    }

    if (exists $term_boosts{$db_accession}) {
      map { $_->setBoost($term_boosts{$db_accession}); } @fields;
    }

    map { $doc->add($_) } @fields;

    $writer->addDocument($doc);
  }
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

  $self->{_index}->optimize();
  $self->{_index}->close();
  $self->{_index} = undef;

  $self->_remove_dir($self->index_path());

  rename($self->_temp_index_path(), $self->index_path());
}

sub _init_lookup
{
  my $self = shift;

  my $analyzer = new Lucene::Analysis::Standard::StandardAnalyzer();
  my $store = Lucene::Store::FSDirectory->getDirectory($self->index_path(), 0);
  my $searcher = new Lucene::Search::IndexSearcher($store);
  my $parser = new Lucene::QueryParser("name", $analyzer);

  $self->{analyzer} = $analyzer;
  $self->{store} = $store;
  $self->{searcher} = $searcher;
  $self->{parser} = $parser;
}

=head2 lookup

 Usage   : my $hits = $index->lookup("cellular_component", \@exclude_subsets,
                                     $search_string, 10);
 Function: Return the search results for the $search_string
 Args    : $search_scope - the ontology_name or subset IDs to restrict the the
                           search to; the subset IDs should be passed as a
                           reference to an array eg.
                           ['GO:0016023',
                           { include => 'GO:0055085', exclude => 'GO:0034762' }]
           $search_exclude - a list of subsets to exclude ie. ignore a result if
                             any of these subset names is a subset_id of a
                             document
           $search_string - the text to search for
           $max_results - the maximum number of results to return
 Returns : the Lucene hits object

=cut
sub lookup
{
  my $self = shift;

  my $search_scope = shift;
  my $search_exclude = shift;
  my $search_string = shift;
  my $max_results = shift;

  if (!defined $search_scope) {
    croak "no search scope passed to lookup()";
  }

  # remove isolated "*" characters
  $search_string =~ s/(?![\w\d_])\*+/ /g;

  # remove non word characters
  $search_string =~ s/[^\w\d_\*]+/ /g;
  $search_string =~ s/\s+/ /g;
  $search_string =~ s/^\s+//;
  $search_string =~ s/\s+$//;

  if (length $search_string == 0) {
    return ();
  }

  my $searcher;
  my $parser;

  if (!defined $self->{searcher}) {
    $self->_init_lookup();
  }

  $searcher = $self->{searcher};
  $parser = $self->{parser};

  my $wildcard;

  $search_string =~ s/\b(or|and)\b/ /gi;
  $search_string =~ s/\s+$//;

  if ($search_string =~ /^(.*?)\W+\w$/) {
    # avoid a single character followed by a wildcard as it triggers
    # a "Too Many Clauses" exception
    $wildcard = " OR text:($1*)";
  } else {
    $wildcard = " OR text:($search_string*)";
  }

  my $query_string = '';

  if (ref $search_scope) {
    $query_string .=
      '(' . (join ' OR ', (map {
        if (ref $_) {
          # change "is_a(GO:0005215)" to "is_a__GO_0005215"
          my $include_id_for_lucene = _id_for_lucene($_->{include});
          my $exclude_id_for_lucene = _id_for_lucene($_->{exclude});

          "(subset_id:$include_id_for_lucene AND NOT subset_id:$exclude_id_for_lucene)";
        } else {
          my $id_for_lucene = _id_for_lucene($_);
          "subset_id:$id_for_lucene";
        }
      } @$search_scope)) . ')';
    $query_string .= ' AND ';
  } else {
    my $ontology_name = $search_scope;
    $ontology_name = lc $ontology_name;
    $ontology_name =~ s/-/_/g;
    $query_string .= qq{cv_name:$ontology_name AND };
  }

  $query_string .=
    qq{(text:($search_string)$wildcard)};

  if ($search_exclude && @$search_exclude > 0) {
    map {
      my $id_for_lucene = _id_for_lucene($_);
      $query_string .= " AND NOT (subset_id:$id_for_lucene)";
    } @$search_exclude;
  }

  my $query = $parser->parse($query_string);

  my $hits = $searcher->search($query);

  my @ret_list = ();
  my %seen_terms = ();
  my $num_hits = $hits->length();

  for (my $i = 0; $i < $num_hits; $i++) {
    my $doc = $hits->doc($i);
    my $cvterm_id = $doc->get('cvterm_id');

    if (!exists $seen_terms{$cvterm_id}) {
      # slightly hacky as we're ignoring some docs
      push @ret_list, { doc => $doc,
                        term_name => $doc->get('term_name'),
                        score => $hits->score($i), };

      $seen_terms{$cvterm_id} = 1;
    }

    # include extra hits in the sort / truncate steps below to
    # decrease the chance that we may a good hit if more than
    # $max_results hits have the same scores
    last if @ret_list >= $max_results * 2;
  }

  # make sure short hits with short term names come first
  my @sorted_results = sort {
    $b->{score} <=> $a->{score}
      ||
    length $a->{term_name} <=> length $b->{term_name};
  } @ret_list;

  # truncate
  if (@sorted_results > $max_results) {
    $#sorted_results = $max_results-1;
  }

  return @sorted_results;
}

sub DESTROY
{
  my $self = shift;

  $self->{_index}->close() if defined $self->{_index};
}

1;
