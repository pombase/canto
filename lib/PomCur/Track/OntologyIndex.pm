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

use Lucene;

with 'PomCur::Role::Configurable';

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

  my $ontology_index_path = _index_path($config);

  remove_tree($ontology_index_path, { error => \my $rm_err } );

  if (@$rm_err) {
    for my $diag (@$rm_err) {
      my ($file, $message) = %$diag;
      warn "error: $message\n";
    }
    exit (1);
  }

  my $init_analyzer = new Lucene::Analysis::Standard::StandardAnalyzer();
  my $store = Lucene::Store::FSDirectory->getDirectory($ontology_index_path, 1);

  my $tmp_writer = new Lucene::Index::IndexWriter($store, $init_analyzer, 1);
  $tmp_writer->close;
  undef $tmp_writer;

  my $analyzer = new Lucene::Analysis::Standard::StandardAnalyzer();
  my $writer = new Lucene::Index::IndexWriter($store, $analyzer, 0);

  $self->{_index} = $writer;
}

sub _index_path
{
  my $config = shift;

  return $config->data_dir_path('ontology_index_file');
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

  my $writer = $self->{_index};

  my $doc = new Lucene::Document;
  my $boost = 0.5 + 100.0 / (10 + length($cvterm->name()));

  my $cv_name = lc $cvterm->cv()->name();
  $cv_name =~ s/-/_/g;

  my $processed_name = $cvterm->name();
  $processed_name =~ s/_/ /g;

  my $name_field = Lucene::Document::Field->Text(name => $processed_name);

  $name_field->setBoost($boost);

  my @fields = (
    $name_field,
    Lucene::Document::Field->Keyword(ontid => $cvterm->db_accession()),
    Lucene::Document::Field->Keyword(cv_name => $cv_name),
    Lucene::Document::Field->Keyword(cvterm_id => $cvterm->cvterm_id()),
  );

  map { $doc->add($_) } @fields;

  $writer->addDocument($doc);
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
}

sub _init_lookup
{
  my $self = shift;

  my $config = $self->config();

  my $analyzer = new Lucene::Analysis::Standard::StandardAnalyzer();
  my $ontology_index_path = _index_path($config);
  my $store = Lucene::Store::FSDirectory->getDirectory($ontology_index_path, 0);
  my $searcher = new Lucene::Search::IndexSearcher($store);
  my $parser = new Lucene::QueryParser("name", $analyzer);

  $self->{analyzer} = $analyzer;
  $self->{store} = $store;
  $self->{searcher} = $searcher;
  $self->{parser} = $parser;
}

=head2 lookup

 Usage   : my $hits = $index->lookup("cellular_component", $search_string, 10);
 Function: Return the search results for the $search_string
 Args    : $ontology_name - the ontology to search
           $search_string - the text to search for
 Returns : the Lucene hits object

=cut
sub lookup
{
  my $self = shift;

  my $config = $self->config();

  # keyword search must be lower case
  my $ontology_name = lc shift;
  $ontology_name =~ s/-/_/g;

  my $search_string = shift;

  my $searcher;
  my $parser;

  if (!defined $self->{searcher}) {
    $self->_init_lookup();
  }

  $searcher = $self->{searcher};
  $parser = $self->{parser};

  my $query;

  if ($search_string =~ /^\s*([a-zA-Z]+:\d+)\s*$/) {
    my $ontid_term = Lucene::Index::Term->new('ontid', $1);
    $query = Lucene::Search::TermQuery->new($ontid_term);
  } else {
    # sanitise
    $search_string =~ s/[^\d\w]+/ /g;
    $search_string =~ s/\s+$//;
    $search_string =~ s/_/ /g;

    my $query_string =
      "cv_name:$ontology_name AND ($search_string OR $search_string*)";

    $query = $parser->parse($query_string);
  }

  return $searcher->search($query);
}

1;

