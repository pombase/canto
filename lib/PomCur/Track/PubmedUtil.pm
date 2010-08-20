package PomCur::Track::PubmedUtil;

=head1 NAME

PomCur::Track::PubmedUtil - Utilities for accessing pubmed.

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::PubmedUtil

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;

use Text::CSV;
use XML::Simple;
use LWP::Simple;

# return an XML string with the pubmed query results for the given ids
sub _get_batch
{
  my $config = shift;
  my @ids = @_;

  my $pubmed_query_url =
    $config->{external_sources}->{pubmed_query_url};

  my $url = $pubmed_query_url . join(',', @ids);

  return get($url);
}

sub _process_batch
{
  my $config = shift;
  my $schema = shift;
  my @ids = @_;

  my $count = 0;

  eval {
    $schema->txn_do(
      sub {
        my $content = _get_batch($config, @ids);
        die "Failed to get results" unless defined $content;

        my $res_hash = XMLin($content);

        for my $article (@{$res_hash->{PubmedArticle}}) {
          my $medline_citation = $article->{MedlineCitation};
          my $pubmedid = $medline_citation->{PMID};
          my $article = $medline_citation->{Article};
          my $title = $article->{ArticleTitle};
          my $abstract = $article->{Abstract}->{AbstractText};

          my $pub = $schema->find_with_type('Pub', { pubmedid => $pubmedid });

          $pub->title($title);
          $pub->abstract($abstract);
          $pub->update();

          $count++;
        }
      });
  };
  if ($@) {
    die "ROLLBACK called: $@\n";
  }

  return $count;
}

=head2

 Usage   : my $count = PomCur::Track::PubmedUtil::add_missing_fields();
 Function: Find publications in the pub table that have no title, query pubmed
           for the missing information and then set the titles
 Args    : $config - the config object
           $schema - the TrackDB object
 Return  : the number of titles added, dies on error

=cut

sub add_missing_fields
{
  my $config = shift;
  my $schema = shift;

  my @missing_field_ids = ();
  my $rs = $schema->resultset('Pub')->search({
    -or => [
      title => undef,
      abstract => undef,
      authors => undef,
    ]
   });
  my $max_batch_size = 10;
  my $count = 0;

  while (defined (my $pub = $rs->next())) {
    my $pubmedid = $pub->pubmedid();

    if (defined $pubmedid) {
      push @missing_field_ids, $pubmedid;

      if (@missing_field_ids == $max_batch_size) {
        $count += _process_batch($config, $schema, @missing_field_ids);
        @missing_field_ids = ();
      }
    }
  }

  if (@missing_field_ids) {
    $count += _process_batch($config, $schema, @missing_field_ids);
  }

  return $count;
}

1;
