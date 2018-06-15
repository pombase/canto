use strict;
use warnings;
use Test::More tests => 4;


use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();

# set pombe as a host organism in pathogen_host_mode
$config->{host_organism_taxonids} = [4896];
$config->_set_host_organisms($track_schema);

my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

my $pombe_organism = $curs_schema->find_with_type('Organism', { taxonid => 4896 });
my $cerevisiae_organism = $curs_schema->create_with_type('Organism', { taxonid => 4932 });

my $existing_pombe_genotype =
  $curs_schema->find_with_type('Genotype', { identifier => 'aaaa0007-genotype-test-1' });

ok ($existing_pombe_genotype);

my $metagenotype = $curs_schema->create_with_type('Genotype',
                                                  {
                                                    identifier => 'metagenotype-1',
                                                  });

$curs_schema->create_with_type('MetagenotypePart',
                               {
                                 metagenotype => $metagenotype,
                                 organism => $pombe_organism,
                                 is_host_part => 0,
                                 genotype => $existing_pombe_genotype,
                               });

$curs_schema->create_with_type('MetagenotypePart',
                               {
                                 metagenotype => $metagenotype,
                                 organism => $cerevisiae_organism,
                                 is_host_part => 1,
                               });

is ($existing_pombe_genotype->metagenotype()->identifier(), 'metagenotype-1');

is ($existing_pombe_genotype->metagenotype_parts()->count(), 1);
is ($metagenotype->metagenotype_parts()->count(), 2);
