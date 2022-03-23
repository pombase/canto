package Canto::Track::PubmedUtil;

=head1 NAME

Canto::Track::PubmedUtil - Utilities for accessing pubmed.

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::PubmedUtil

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

use strict;
use warnings;
use Carp;
use Moose;
use feature ':5.10';

use Text::CSV;
use XML::Simple;
use LWP::UserAgent;

use Canto::Track::LoadUtil;

my $max_batch_size = 300;

sub _get_url
{
  my $config = shift;
  my $url = shift;

  my $ua = LWP::UserAgent->new;
  $ua->agent($config->get_application_name());

  my $req = HTTP::Request->new(GET => $url);

  my $res;

  for my $try (1..5) {
    $res = $ua->request($req);

    if ($res->is_success) {
      if ($res->content()) {
        my $decoded_content = $res->decoded_content(charset => 'utf-8');
        return $decoded_content;
      } else {
        die "query returned no content: $url";
      }
    } else {
      warn "failed to get $url\n  - retrying\n";
      # wait a bit and try again
      sleep 1.5;
    }
  }

  die "Couldn't read from $url: ", $res->status_line, "\n";
}

=head2 get_pubmed_xml_by_ids

 Usage   : my $xml = Canto::Track::PubmedUtil::get_pubmed_xml_by_ids($config,
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

=head2 get_pubmed_ids_by_query

 Usage   : my $xml = Canto::Track::PubmedUtil::get_pubmed_ids_by_query($config, $text);
 Function: Return a list of PubMed IDs of the articles that match the given
           text (in the title or abstract)
 Args    : $config - the config object
           $text - the query
 Returns : XML containing the matching IDs

=cut

sub get_pubmed_ids_by_query
{
  my $config = shift;
  my $text = shift;

  my $pubmed_query_url =
    $config->{external_sources}->{pubmed_esearch_url};

  my $url = $pubmed_query_url . $text;

  return _get_url($config, $url);
}


our $PUBMED_PREFIX = "PMID";

sub _remove_tag {
  my $text = shift;
  $text =~ s/<[^>]+>/ /g;
  return $text;
}

my %month_map =
  ("Jan" => "01",
   "Feb" => "02",
   "Mar" => "03",
   "Apr" => "04",
   "May" => "05",
   "Jun" => "06",
   "Jul" => "07",
   "Aug" => "08",
   "Sep" => "09",
   "Oct" => "10",
   "Nov" => "11",
   "Dec" => "12",
   );

=head2 load_pubmed_xml

 Usage   : my $count = Canto::Track::PubmedUtil::load_pubmed_xml($schema, $xml);
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

  # Awful hack to remove italics and other tags in titles and abstracts.
  # This prevents parsing problems, see:
  # https://github.com/pombase/pombase-chado/issues/663
  for my $tag_name ('ArticleTitle', 'AbstractText') {
    $content =~ s|<$tag_name>(.+?)</$tag_name>|"<$tag_name>" . _remove_tag($1) . "</$tag_name>"|egs;
  }

  my $load_util = Canto::Track::LoadUtil->new(schema => $schema);

  my $res_hash = XMLin($content,
                       ForceArray => ['AbstractText',
                                      'Author', 'PublicationType']);

  my $guard = $schema->txn_scope_guard();

  my $count = 0;
  my @articles;

  if (defined $res_hash->{PubmedArticle}) {
    if (ref $res_hash->{PubmedArticle} eq 'ARRAY') {
      @articles = @{$res_hash->{PubmedArticle}};
    } else {
      push @articles, $res_hash->{PubmedArticle};
    }

    my $pubmed_type_cv = $load_util->find_cv('PubMed publication types');
    my $pubmed_review_term = undef;
    my $pubmed_paper_term = undef;

    for my $article (@articles) {
      my $medline_citation = $article->{MedlineCitation};
      my $uniquename = "$PUBMED_PREFIX:" . $medline_citation->{PMID}->{content};

      if (!defined $uniquename) {
        die "PubMed ID not found in XML\n";
      }

      my $article = $medline_citation->{Article};
      my $title = $article->{ArticleTitle};

      if (!defined $title || length $title == 0) {
        warn "No title for $uniquename - can't load";
        next;
      }

      my $affiliation = $article->{Affiliation} // '';

      my $authors = '';
      my $author_detail = $article->{AuthorList}->{Author};
      if (defined $author_detail) {
        my @author_elements = @{$author_detail};
        $authors = join ', ', map {
          if (defined $_->{CollectiveName}) {
            $_->{CollectiveName};
          } else {
            if (defined $_->{LastName}) {
              if (defined $_->{Initials}) {
                $_->{LastName} . ' ' . $_->{Initials};
              } else {
                $_->{LastName};
              }
            } else {
              warn "missing author details in: $uniquename\n";
              ();
            }
          }
        } @author_elements;
      }

      my $abstract_text = $article->{Abstract}->{AbstractText};
      my $abstract;

      if (ref $abstract_text eq 'ARRAY') {
        $abstract = join ("\n",
                          map {
                            if (ref $_ eq 'HASH') {
                              if (defined $_->{content}) {
                                if (ref $_->{content}) {
                                  ();
                                } else {
                                  $_->{content};
                                }
                              } else {
                                ();
                              }
                            } else {
                              $_;
                            }
                          } @$abstract_text);
      } else {
        $abstract = $abstract_text // '';
      }

      my $pubmed_type;

      my @publication_types =
        @{$article->{PublicationTypeList}->{PublicationType}};

      for my $pub_type (@publication_types) {
        if ($pub_type eq 'Review') {
          $pubmed_type =
            ($pubmed_review_term //=
               $load_util->find_cvterm(cv => $pubmed_type_cv,
                                       name => 'review'));
        }
      }

      if (!defined $pubmed_type) {
        $pubmed_type =
          ($pubmed_paper_term //=
             $load_util->find_cvterm(cv => $pubmed_type_cv,
                                     name => 'paper'));
      }

      my $citation = '';
      my $publication_date = '';

      if (defined $article->{Journal}) {
        my $journal = $article->{Journal};
        $citation =
          $journal->{ISOAbbreviation} // $journal->{Title} //
          'Unknown journal';

        if (defined $journal->{JournalIssue}) {
          my $journal_issue = $journal->{JournalIssue};
          my $pub_date = $journal_issue->{PubDate};

          if (defined $pub_date) {
            my $pub_date = $journal_issue->{PubDate};
            my @date_bits = ($pub_date->{Year} // (),
                             $pub_date->{Month} // (),
                             $pub_date->{Day} // ());

            if (!@date_bits) {
              my $medline_date = $pub_date->{MedlineDate};
              if (defined $medline_date &&
                  $medline_date =~ /(\d\d\d\d)(?:\s+(\w+)(?:\s+(\d+))?)?/) {
                @date_bits = ($1, $2 // (), $3 // ());
              }
            }

            my $cite_date = join (' ', @date_bits);
            $citation .= ' ' . $cite_date;

            if ($date_bits[1] && $month_map{$date_bits[1]}) {
              $date_bits[1] = $month_map{$date_bits[1]};
            }

            $publication_date = join (' ', @date_bits);
          }
          $citation .= ';';
          if (defined $journal_issue->{Volume}) {
            $citation .= $journal_issue->{Volume};
          }
          if (defined $journal_issue->{Issue}) {
            $citation .= '(' . $journal_issue->{Issue} . ')';
          }
        }
      }

      if (defined $article->{Pagination}) {
        my $pagination = $article->{Pagination};
        if (defined $pagination->{MedlinePgn} &&
            !ref $pagination->{MedlinePgn}) {
          $citation .= ':' . $pagination->{MedlinePgn};
        }
      }

      my $pub = $load_util->get_pub($uniquename, $load_type);

      $pub->title($title);
      $pub->authors($authors);
      $pub->abstract($abstract);
      $pub->affiliation($affiliation);
      $pub->citation($citation);
      $pub->publication_date($publication_date);
      $pub->pubmed_type($pubmed_type->cvterm_id());
      $pub->update();

      $count++;
    }
  }

  $guard->commit();

  return $count;
}

sub _process_batch
{
  my $config = shift;
  my $schema = shift;
  my $ids = shift;
  my @ids = @$ids;
  my $load_type = shift;

  my $count = 0;

  my $content = get_pubmed_xml_by_ids($config, @ids);
  $count += load_pubmed_xml($schema, $content, $load_type);

  return $count;
}

=head2 load_by_ids

 Usage   : my $count = Canto::Track::PubmedUtil::load_by_ids(...)
 Function: Load the publications with the given ids into the track
           database.
 Args    : $config - the config object
           $schema - the TrackDB object
           $ids - an array ref of ids of publications to load, with
                  optional "PMID:" prefix
           $load_type - a cvterm from the "Publication load types" CV
                    that records who is loading this publication
 Returns : a count of the number of publications found and loaded

=cut

sub load_by_ids
{
  my $config = shift;
  my $schema = shift;
  my $ids = shift;
  my $load_type = shift;

  my $count = 0;

  while (@$ids) {
    my @process_ids = map { s/^PMID://; $_; } splice(@$ids, 0, $max_batch_size);

    $count += _process_batch($config, $schema, [@process_ids], $load_type);

    sleep 10;
  }

  return $count;
}

=head2 load_by_query

 Usage   : my $count = Canto::Track::PubmedUtil::load_by_query(...)
 Function: Send a query to PubMed and load the publications it returns
           into the track database.
 Args    : $config - the config object
           $schema - the TrackDB object
           $query - a PubMed query string
           $load_type - a cvterm from the "Publication load types" CV
                    that records who is loading this publication
 Returns : a count of the number of publications found and loaded

=cut

sub load_by_query
{
  my $config = shift;
  my $schema = shift;
  my $query = shift;
  my $load_type = shift;

  my $count = 0;

  my $xml = get_pubmed_ids_by_query($config, $query);
  my $res_hash = XMLin($xml);

  if (!defined $res_hash->{IdList}->{Id}) {
    my $warning_list = $res_hash->{WarningList};
    if (defined $warning_list) {
      my $output_mesasge = $warning_list->{OutputMessage};
      if (ref $output_mesasge eq 'ARRAY') {
        die join ('  ', @$output_mesasge), "\n";;
      } else {
        die "$output_mesasge\n";
      }
    }

    die "PubMed query failed, but returned no error\n";
  }

  my @ids = @{$res_hash->{IdList}->{Id}};

  my %db_ids = ();

  map {
    my $uniquename = $_->uniquename();
    if ($uniquename =~ /^$PUBMED_PREFIX:(\d+)$/) {
      $db_ids{$1} = 1;
    }
  } $schema->resultset('Pub')->search({}, { columns => ['uniquename'] })->all();

  @ids = grep {
    !$db_ids{$_};
  } @ids;

  while (@ids) {
    my @process_ids = splice(@ids, 0, $max_batch_size);

    $count += _process_batch($config, $schema, [@process_ids], $load_type);
  }

  return $count;
}



=head2

 Usage   : my $count = Canto::Track::PubmedUtil::add_missing_fields();
 Function: Find publications in the pub table that have no title, query pubmed
           for the missing information and then set the titles
 Args    : $config - the config object
           $schema - the TrackDB object
 Returns : the number of publications updated, dies on error

=cut

sub add_missing_fields
{
  my $config = shift;
  my $schema = shift;

  my $rs = $schema->resultset('Pub')->search({
    -or => [
      title => undef,
      abstract => undef,
      authors => undef,
      affiliation => undef,
      pubmed_type => undef,
      citation => undef,
      publication_date => undef,
      \'length(publication_date) = 0',
    ]
   });
  my $max_batch_size = 300;
  my $count = 0;

  return load_by_ids($config, $schema,
                     [map { $_->uniquename() } $rs->all()],
                     'admin_load');
}


=head2 update_field

 Usage   : my $count = Canto::Track::PubmedUtil::update_field($config, $schema,
                                                              "publication_date");
 Function: Set the field with the given name to undef/null in the database, then
           re-initialise it from the PubMed data
 Args    : $config - the config object
           $schema - the TrackDB object
           $field_name - the field to re-initialise
 Returns : the number of publications updated, dies on error

=cut

sub update_field
{
  my $config = shift;
  my $schema = shift;
  my $field_name = shift;

  if ($field_name eq 'uniquename') {
    die "can't update uniquename field\n";
  }

  my $pub_rs = $schema->resultset('Pub');

  $pub_rs->update({ $field_name => undef });

  return add_missing_fields($config, $schema);
}

1;
