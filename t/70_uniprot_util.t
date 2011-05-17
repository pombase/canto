use strict;
use warnings;
use Test::More tests => 1;

use PomCur::TestUtil;
use PomCur::UniProt::UniProtUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();

my $xml_filename = $config->{test_config}->{test_uniprot_entries};
my $xml_file_full_path = $test_util->test_data_dir_full_path($xml_filename);

my @results = PomCur::UniProt::UniProtUtil::_parse_results($xml_file_full_path);

is (@results, 2);
