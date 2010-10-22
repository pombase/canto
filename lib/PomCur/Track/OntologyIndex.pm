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

use KinoSearch::Index::Indexer;
use KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::Highlight::Highlighter;
use KinoSearch::Plan::Schema;
use KinoSearch::Plan::FullTextType;
use KinoSearch::Search::IndexSearcher;

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
  my $analyzer = _get_analyzer();

  my $ontology_index_path = _index_path($config);

  remove_tree($ontology_index_path, { error => \my $rm_err } );

  if (@$rm_err) {
    for my $diag (@$rm_err) {
      my ($file, $message) = %$diag;
      warn "error: $message\n";
    }
    exit (1);
  }

  my $schema = KinoSearch::Plan::Schema->new;

  my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
    language => 'en',
  );

  my $indexer = KinoSearch::Index::Indexer->new(
    index    => $ontology_index_path,
    schema   => $schema,
    create   => 1,
    truncate => 1,
  );

  my $type = KinoSearch::Plan::FullTextType->new(
    analyzer => $polyanalyzer,
  );

  $schema->spec_field(
    name  => 'name',
    type => $type,
#    boost => 3,
  );
  $schema->spec_field(
    name  => 'ontid',
    type => $type,
  );
  $schema->spec_field(
    name  => 'cvterm_id',
    type => $type,
  );
  $schema->spec_field(
    name  => 'cv_name',
    type => $type,
  );

  $self->{_index} = $indexer;
}

sub _get_analyzer
{
  return KinoSearch::Analysis::PolyAnalyzer->new(language => 'en');
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

  my $index = $self->{_index};

  $index->add_doc(
    {
      ontid => $cvterm->db_accession(),
      name => $cvterm->name(),
      cv_name => $cvterm->cv()->name(),
      cvterm_id => $cvterm->cvterm_id()
    });
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

  $self->{_index}->commit();
}

sub lookup
{
  my $self = shift;
  my $ontology_name = shift;
  my $search_string = shift;
  my $max_results = shift;

  my $analyzer = _get_analyzer();

  my $searcher = KinoSearch::Search::IndexSearcher->new(
    index => _index_path($self->config())
  );

  my $hits = $searcher->hits(query => $search_string, num_wanted => 10);

#  my $highlighter =
#    KinoSearch::Highlight::Highlighter->new(excerpt_field => 'name');

#  $hits->create_excerpts(highlighter => $highlighter);

#  $hits->seek(0, $max_results);

  return $hits;
}

1;
