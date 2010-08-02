use strict;
use warnings;
use Test::More tests => 4;

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

  my $xml_file_name = $test_util->root_dir() . '/t/data/entrez_pubmed.xml';
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
my $schema = PomCur::TrackDB->new($config);

my @pub_results = $schema->resultset('Pub')->search();

isnt(@pub_results, 0);

my $defined_title_count = 0;

for my $pub (@pub_results) {
  $defined_title_count++ if defined $pub->title();
}

my $count = PomCur::Track::PubmedUtil::add_missing_titles($config, $schema);

is($count, 3);

my @new_pub_results = $schema->resultset('Pub')->search();

is(@new_pub_results, @pub_results);

my $new_defined_title_count = 0;

for my $pub (@new_pub_results) {
  $new_defined_title_count++ if defined $pub->title();
  warn $pub->pubmedid() unless defined $pub->title();
}

is($new_defined_title_count, @pub_results);
