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

use Lucy::Index::Indexer;
use Lucy::Plan::Schema;
use Lucy::Analysis::EasyAnalyzer;
use Lucy::Plan::FullTextType;
use Lucy::Plan::StringType;
use Lucy::Search::IndexSearcher;
use Lucy::Analysis::PolyAnalyzer;
use Lucy::Search::QueryParser;
use Lucy::Search::ORQuery;
use Lucy::Search::ANDQuery;
use Lucy::Search::NOTQuery;
use LucyX::Search::WildcardQuery;

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

  my $schema = Lucy::Plan::Schema->new();
  my $easyanalyzer = Lucy::Analysis::EasyAnalyzer->new(
    language => 'en',
  );
  my $full_text_type = Lucy::Plan::FullTextType->new(
    analyzer => $easyanalyzer,
  );

  my $whitespace_tokenizer
    = Lucy::Analysis::RegexTokenizer->new( pattern => '\S+' );

  my $ws_polyanalyzer = Lucy::Analysis::PolyAnalyzer->new(
    analyzers => [ $whitespace_tokenizer ],
  );

  my $keyword_type = Lucy::Plan::FullTextType->new(
    analyzer => $ws_polyanalyzer,
  );

  my $string_type = Lucy::Plan::StringType->new();
  my $unindexed_string_type = Lucy::Plan::StringType->new(indexed => 0);

  $schema->spec_field(name => 'text', type => $full_text_type);
  $schema->spec_field(name => 'ontid', type => $string_type);
  $schema->spec_field(name => 'cv_name', type => $string_type);
  $schema->spec_field(name => 'cvterm_id', type => $string_type);
  $schema->spec_field(name => 'term_name', type => $string_type);

  for (my $i = 0; $i < 10; $i++) {
    $schema->spec_field(name => "subset_${i}_id", type => $keyword_type);
  }

  # Create the index and add documents.
  my $indexer = Lucy::Index::Indexer->new(
    schema => $schema,
    index  => $self->_temp_index_path(),
    create => 1,
  );

  $self->{_index} = $indexer;
  $self->{_schema} = $schema;;
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

  my $indexer = $self->{_index};

  # $text can be the name or a synonym
  for my $details (_get_all_names($term_name, $synonym_details)) {
    my $type = $details->[0];
    my $text = $details->[1];

    my @subset_ids =
      (map {
        # change "is_a(GO:0005215)" to "is_a__GO_0005215"
        _id_for_lucene($_);
      } @$subset_ids);

    my %doc = (
      text => $text,
      ontid => $db_accession,
      cv_name => $cv_name,
      cvterm_id => $cvterm_id,
      term_name => $term_name,
    );

    for (my $i = 0; $i < @subset_ids; $i++) {
      $doc{"subset_${i}_id"} = $subset_ids[$i];
    }

    $indexer->add_doc(\%doc)

#    if (exists $synonym_boosts{$type}) {
#      map { $_->setBoost($synonym_boosts{$type}); } @fields;
#    }
#
#    if (exists $term_boosts{$db_accession}) {
#      map { $_->setBoost($term_boosts{$db_accession}); } @fields;
#    }
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

  my $indexer = $self->{_index};

  $indexer->commit();

  $self->_remove_dir($self->index_path());

  rename($self->_temp_index_path(), $self->index_path());
}

sub _init_lookup
{
  my $self = shift;

  my $searcher = Lucy::Search::IndexSearcher->new(index => $self->index_path());

  $self->{searcher} = $searcher;
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

  my $searcher;

  if (!defined $self->{searcher}) {
    $self->_init_lookup();
  }

  $searcher = $self->{searcher};

  my $indexer = $self->{_index};

  $search_string =~ s/\b(or|and)\b/ /gi;
  $search_string =~ s/\s+$//;

  warn "search_string: $search_string";
use Data::Dumper;
$Data::Dumper::Maxdepth = 3;
warn 'scope: ', Dumper([$search_scope]);
use Data::Dumper;
$Data::Dumper::Maxdepth = 3;
warn 'exclude: ', Dumper([$search_exclude]);

  my @search_parts = split /\s+/, $search_string;

  if (@search_parts == 0 ||
      @search_parts == 1 && length $search_parts[0] <=2) {
    return ();
  }

  my $query_parser = Lucy::Search::QueryParser->new(
    schema => $searcher->get_schema(),
  );
  $query_parser->set_heed_colons(1);

  warn "@search_parts";

  my @or_parts = map {
    (LucyX::Search::WildcardQuery->new(
      term    => "$_*",
      field   => 'text',
    ),
     $query_parser->parse("text:$_"),
   )
  } @search_parts;

  my $text_query =
    Lucy::Search::ORQuery->new(children => \@or_parts);

  my @and_parts = ();


  my $scope_query_string = '';

  if (ref $search_scope) {
    $scope_query_string .=
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
  } else {
    my $ontology_name = $search_scope;
    $ontology_name = lc $ontology_name;
    $ontology_name =~ s/-/_/g;
    $scope_query_string .="cv_name:$ontology_name";
  }

warn "scope_query_string: $scope_query_string";

  my $parsed_scope_query = $query_parser->parse($scope_query_string);

  push @and_parts, $parsed_scope_query, $text_query;

  if ($search_exclude && @$search_exclude > 0) {
    map {
      my $id_for_lucene = _id_for_lucene($_);
      push @and_parts,
        Lucy::Search::NOTQuery->new(negated_query =>
                                    $query_parser->parse("subset_id:$id_for_lucene"));
    } @$search_exclude;
  }

#  my $schema = $self->{_schema};
#
#  my %fields;
#  for my $field_name ( @{ $schema->all_fields() } ) {
#    $fields{$field_name} = {
#      type     => $schema->fetch_type($field_name),
#      analyzer => $schema->fetch_analyzer($field_name),
#    };
#  }
#
#  my $query_parser = Search::Query->parser(
#     dialect        => 'Lucy',
#     fuzzify        => 1,
#     croak_on_error => 1,
#     default_field  => 'text',  # applied to "bare" terms with no field
#     fields         => \%fields,
# );
#

# my $lucy_query   = $parsed_query->as_lucy_query();

#warn "stringify: ", $parsed_query->stringify();

  my $and_query = Lucy::Search::ANDQuery->new(children => \@and_parts);

  use Data::Dumper;
  warn Dumper([$and_query->to_string()]);



  my $hits =
    $searcher->hits(query => $text_query,
                    num_wanted => $max_results * 2);

  my @ret_list = ();
  my %seen_terms = ();

  while (my $hit = $hits->next()) {

    my $cvterm_id = $hit->{'cvterm_id'};

    if (!exists $seen_terms{$cvterm_id}) {
      # slightly hacky as we're ignoring some docs
      push @ret_list,
        {
          doc => $hit->get_fields(),
          term_name => $hit->{term_name},
          score => $hit->get_score()
        };

      $seen_terms{$cvterm_id} = 1;
    }
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

1;
