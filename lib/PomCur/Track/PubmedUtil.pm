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
use LWP::UserAgent;

use PomCur::Track::LoadUtil;

sub _get_url
{
  my $config = shift;
  my $url = shift;

  my $ua = LWP::UserAgent->new;
  $ua->agent($config->get_application_name());

  my $req = HTTP::Request->new(GET => $url);
  my $res = $ua->request($req);

  if ($res->is_success) {
    return $res->content;
  } else {
    die "Couldn't read from $url: ", $res->status_line, "\n";
  }
}

=head2 get_pubmed_xml_by_ids

 Usage   : my $xml = PomCur::Track::PubmedUtil::get_pubmed_xml_by_ids($config,
                                                                      @ids);
 Function: Return an XML chunk from pubmed with information about the
           publications with IDs given by @ids
 Args    : $config - the config object
           @ids - the pubmed ids to search for
 Returns : The XML from pubmed

=cut
sub get_pubmed_xml_by_ids
{
  my $config = shift;
  my @ids = @_;

  my $pubmed_query_url =
    $config->{external_sources}->{pubmed_efetch_url};

  my $url = $pubmed_query_url . join(',', @ids);

  return _get_url($config, $url);
}

=head2 get_pubmed_ids_by_text

 Usage   : my $xml = PomCur::Track::PubmedUtil::get_pubmed_xml_by_text($config,
                                                                       $text);
 Function: Return a list of PubMed IDs of the articles that match the given
           text (in the title or abstract)
 Args    : $config - the config object
           $text - the text
 Returns : XML containing the matching IDs

=cut
sub get_pubmed_xml_by_text
{
  my $config = shift;
  my $text = shift;

  my $pubmed_query_url =
    $config->{external_sources}->{pubmed_esearch_url};

  my $url = $pubmed_query_url . $text;

  return _get_url($config, $url);
}

our $PUBMED_PREFIX = "PMID";

=head2 load_pubmed_xml

 Usage   : my $count = PomCur::Track::PubmedUtil::load_pubmed_xml($schema, $xml);
 Function: Load the given pubmed XML in the database
 Args    : $schema - the schema to load into
           $xml - a string holding an XML fragment about containing some
                  publications from pubmed
           $load_type - a cvterm from the "Publication load types" CV that
                        records who is loading this publication
 Returns : the count of number of publications loaded

=cut
sub load_pubmed_xml
{
  my $schema = shift;
  my $content = shift;
  my $load_type = shift;

  if (!defined $load_type) {
    croak("no load_type passed to load_pubmed_xml()");
  }

  my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);

  my $res_hash = XMLin($content,
                       ForceArray => ['AbstractText']);

  my $count = 0;
  my @articles;

  if (defined $res_hash->{PubmedArticle}) {
    if (ref $res_hash->{PubmedArticle} eq 'ARRAY') {
      @articles = @{$res_hash->{PubmedArticle}};
    } else {
      push @articles, $res_hash->{PubmedArticle};
    }

    for my $article (@articles) {
      my $medline_citation = $article->{MedlineCitation};
      my $uniquename = "$PUBMED_PREFIX:" . $medline_citation->{PMID}->{content};

      if (!defined $uniquename) {
        die "PubMed ID not found in XML\n";
      }

      my $article = $medline_citation->{Article};
      my $title = $article->{ArticleTitle};
      my $abstract_text = $article->{Abstract}->{AbstractText};

      my $abstract;

      if (ref $abstract_text eq 'ARRAY') {
        $abstract = join ("\n",
                          map {
                            if (ref $_ eq 'HASH') {
                              $_->{content};
                            } else {
                              $_;
                            }
                          } @$abstract_text);
      } else {
        $abstract = $abstract_text;
      }

      my $pub = $load_util->get_pub($uniquename, $load_type);

      $pub->title($title);
      $pub->abstract($abstract);
      $pub->update();

      $count++;
    }
  }

  return $count;
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
        my $content = get_pubmed_xml_by_ids($config, @ids);
        die "Failed to get results" unless defined $content;

        $count += load_pubmed_xml($schema, $content);
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
    my $uniquename = $pub->uniquename();

    if (defined $uniquename) {
      push @missing_field_ids, $uniquename;

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
