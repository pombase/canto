use strict;
use warnings;
use Test::More tests => 45;

use PomCur::TestUtil;
use PomCur::Track::PubmedUtil;
use PomCur::TrackDB;

my $test_util;

BEGIN {
  $test_util = PomCur::TestUtil->new();
}

package PomCur::Track::PubmedUtil;

no warnings;

# override for testing
sub _get_batch
{
  local ($/) = undef;

  my $xml_file_name = $test_util->publications_xml_file();
  open my $pubmed_xml, '<', $xml_file_name
    or die "can't open '$xml_file_name': $!";

  my $ret_val = <$pubmed_xml>;

  close $pubmed_xml or die "$!";

  return $ret_val;
}

use warnings;

package main;

$test_util->init_test();

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @pub_results = $schema->resultset('Pub')->search();

isnt(@pub_results, 0);

my $defined_count = 0;

for my $pub (@pub_results) {
  $defined_count++ if defined $pub->title();
}

my $xml = $test_util->get_pubmed_test_xml();
my $count = PomCur::Track::PubmedUtil::load_pubmed_xml($schema, $xml);

is($count, 21);

my @new_pub_results = $schema->resultset('Pub')->search();

is(@new_pub_results, @pub_results);

for my $pub (@new_pub_results) {
  # all should have titles
  ok(defined $pub->title());
  ok(defined $pub->abstract(), "has abstract: " . $pub->pubmedid());
}
