use strict;
use warnings;
use Test::More tests => 10;

use Try::Tiny;

use Canto::TestUtil;

use Canto::UniProt::GeneLookup;

my $test_util = Canto::TestUtil->new();
$test_util->init_test();

my $config = $test_util->config();
my $track_schema = Canto::TrackDB->new(config => $config);

my $organism_count_before = $track_schema->resultset('Organism')->count();
my $gene_count_before = $track_schema->resultset('Gene')->count();

my $xml_filename = $config->{test_config}->{test_uniprot_entries};
my $xml_file_full_path = $test_util->test_data_dir_full_path($xml_filename);

my $gene_lookup = Canto::UniProt::GeneLookup->new(config => $test_util->config(),
                                                  schema => $track_schema);

$gene_lookup->meta()->remove_method('_get_results');
$gene_lookup->meta()->add_method('_get_results',
                                 sub {
                                   return Canto::UniProt::UniProtUtil::parse_results($xml_file_full_path);
                                 });

my $res_from_xml = $gene_lookup->lookup(['P15436', 'O74473', 'Q06Y82', 'MISSING_ID']);

is (scalar @{$res_from_xml->{found}}, 4);
is (scalar @{$res_from_xml->{missing}}, 1);

is ($res_from_xml->{found}->[0]->{primary_name}, "POL3");
is ($res_from_xml->{found}->[1]->{primary_name}, "cdc11");
is ($res_from_xml->{found}->[2]->{organism_taxonid}, "4896");
is ($res_from_xml->{found}->[3]->{primary_name}, "BRW65_00080");


# The genes should now be in the TrackDB so _get_results() won't be called.
# fail() if it is called.
$gene_lookup->meta()->remove_method('_get_results');
$gene_lookup->meta()->add_method('_get_results',
                                 sub {
                                   fail();
                                 });

my $res_from_track = $gene_lookup->lookup(['P15436', 'O74473', 'Q06Y82', 'MISSING_ID']);

is (scalar @{$res_from_track->{found}}, 4);
is (scalar @{$res_from_track->{missing}}, 1);

my $organism_count_after = $track_schema->resultset('Organism')->count();
is ($organism_count_before + 3, $organism_count_after);

my $gene_count_after = $track_schema->resultset('Gene')->count();
is ($gene_count_before + 4, $gene_count_after);
