use strict;
use warnings;
use Test::More tests => 19;

use Canto::TestUtil;
use Canto::UniProt::UniProtUtil;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();

my $xml_filename = $config->{test_config}->{test_uniprot_entries};
my $xml_file_full_path = $test_util->test_data_dir_full_path($xml_filename);

my @results = Canto::UniProt::UniProtUtil::parse_results($xml_file_full_path);

is ($results[0]->{primary_name}, 'POL3');
is ($results[0]->{primary_identifier}, 'P15436');
is ($results[0]->{product}, 'DNA polymerase delta catalytic subunit');
is ($results[0]->{organism_full_name}, 'Saccharomyces cerevisiae (strain ATCC 204508 / S288c)');
is ($results[0]->{organism_taxonid}, '559292');
is ($results[0]->{synonyms}->[0], 'CDC2');
is ($results[0]->{synonyms}->[1], 'TEX1');
is ($results[0]->{synonyms}->[2], 'YDL102W');
is ($results[0]->{synonyms}->[3], 'D2366');
is (@{$results[0]->{synonyms}}, 4);

is ($results[1]->{primary_name}, 'cdc11');
is ($results[1]->{primary_identifier}, 'O74473');
is ($results[1]->{product}, 'Septation initiation network scaffold protein cdc11');
is ($results[1]->{organism_full_name}, 'Schizosaccharomyces pombe (strain ATCC 38366 / 972)');
is ($results[1]->{organism_taxonid}, '284812');
is ($results[1]->{synonyms}->[0], 'SPCC1739.11c');

is ($results[2]->{primary_identifier}, 'Q06Y82');
is ($results[2]->{product}, 'Cytochrome c oxidase subunit 2');

is (@results, 4);
