#!/usr/bin/perl -w

use strict;
use warnings;
use Carp;

use Text::CSV;
use XML::Simple;
use LWP::Simple;

BEGIN {
  $ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';
}

use PomCur::TrackDB;
use PomCur::Config;

my $config = PomCur::Config::get_config();
my $schema = PomCur::TrackDB->new($config);

my $pubmed_query_url =
  $config->{external_sources}->{pubmed_query_url};

my @missing_title_ids = ();

my $rs = $schema->resultset('Pub')->search({title => undef});

my $max_batch_size = 10;

my $count = 0;

sub process_batch
{
  my @ids = @_;

  eval {
    $schema->txn_do(
      sub {
        my $url = $pubmed_query_url . join(',', @ids);

        my $content = get($url);
        die "Failed to get results from $url" unless defined $content;

        my $res_hash = XMLin($content);

        for my $article (@{$res_hash->{PubmedArticle}}) {

          my $medline_citation = $article->{MedlineCitation};

          my $pubmedid = $medline_citation->{PMID};
          my $title = $medline_citation->{Article}->{ArticleTitle};

#          print $medline_citation->{Article}->{Abstract}->{AbstractText},"\n";

          my $pub = $schema->find_with_type('Pub', { pubmedid => $pubmedid });

          $pub->title($title);
          $pub->update();

          $count++;
        }

        print "added titles to $count publications\n";
      });
  };
  if ($@) {
    die "ROLLBACK called: $@\n";
  }
}

while (defined (my $pub = $rs->next())) {
  my $pubmedid = $pub->pubmedid();

  if (defined $pubmedid) {
    push @missing_title_ids, $pubmedid;

    if (@missing_title_ids == $max_batch_size) {
      process_batch(@missing_title_ids);
      @missing_title_ids = ();
    }
  }
}

if (@missing_title_ids) {
  process_batch(@missing_title_ids);
}
