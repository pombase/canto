use strict;
use warnings;
use Test::More tests => 7;

use Canto::TestUtil;
use Canto::Track::OrganismLookup;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();

# set pombe as a host organism in pathogen_host_mode
$config->{host_organism_taxonids} = [4932];
$config->_set_host_organisms($track_schema);
$Canto::Track::OrganismLookup::cache = {};

my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

my $existing_pombe_genotype =
  $curs_schema->find_with_type('Genotype', { identifier => 'aaaa0007-genotype-test-1' });

ok ($existing_pombe_genotype);

my $genotype_manager = Canto::Curs::GenotypeManager->new(config => $config,
                                                         curs_schema => $curs_schema);
my $cerevisiae_genotype =
  $genotype_manager->make_genotype(undef, undef, [], 4932);

my $metagenotype =
  $genotype_manager->make_metagenotype(pathogen_genotype => $existing_pombe_genotype,
                                       host_genotype => $cerevisiae_genotype);

is ($metagenotype->identifier(), 'aaaa0007-metagenotype-1');

is ($metagenotype->metagenotype_id(),
    ($cerevisiae_genotype->metagenotypes())[0]->metagenotype_id());

is ($metagenotype->metagenotype_id(),
    ($existing_pombe_genotype->metagenotypes())[1]->metagenotype_id());

my $lookup_metagenotype =
  $genotype_manager->find_metagenotype(pathogen_genotype => $existing_pombe_genotype,
                                       host_genotype => $cerevisiae_genotype);

is ($lookup_metagenotype->identifier(), 'aaaa0007-metagenotype-1');

is ($lookup_metagenotype->metagenotype_id(),
    ($cerevisiae_genotype->metagenotypes())[0]->metagenotype_id());

is ($lookup_metagenotype->metagenotype_id(),
    ($existing_pombe_genotype->metagenotypes())[1]->metagenotype_id());
