use strict;
use warnings;
use Test::More tests => 9;
use Test::Deep;

use Data::Compare;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

use Canto::TestUtil;
use Canto::Controller::Curs;
use Canto::Curs::Utils;
use Canto::Track::OrganismLookup;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('1_curs');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();

my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);
my $curs_key = $curs_objects[0]->curs_key();

my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $gene_manager = Canto::Curs::GeneManager->new(config => $config,
                                                 curs_schema => $curs_schema);

my @search_genes = qw(SPCC1739.10 mot1 SPNCRNA.119);

is ($curs_schema->resultset('Gene')->count(), 0);

my ($result) =
  $gene_manager->find_and_create_genes(\@search_genes);

is ($curs_schema->resultset('Gene')->count(), 3);

my $first = $curs_schema->resultset('Gene')->first();

my $organism_lookup = Canto::Track::get_adaptor($config, 'organism');
my $lookup_organism = $organism_lookup->lookup_by_taxonid($first->organism()->taxonid());

is ($lookup_organism->{pathogen_or_host}, 'unknown');


##########################################

$curs_schema->resultset('Gene')->delete();
$curs_schema->resultset('Organism')->delete();

is ($curs_schema->resultset('Gene')->count(), 0);


# set pombe as a host organism in pathogen_host_mode
$config->{host_organism_taxonids} = [4896];
$config->_set_host_organisms($track_schema);
$Canto::Track::OrganismLookup::cache = {};

($result) = $gene_manager->find_and_create_genes(\@search_genes);

is ($curs_schema->resultset('Gene')->count(), 3);

my $first_host_gene = $curs_schema->resultset('Gene')->first();

my $lookup_host_organism =
  $organism_lookup->lookup_by_taxonid($first_host_gene->organism()->taxonid());

is ($lookup_host_organism->{pathogen_or_host}, 'host');


##########################################

$curs_schema->resultset('Gene')->delete();
$curs_schema->resultset('Organism')->delete();

# fake pathogen_host_mode with no host so pombe will be a "pathogen"
$config->{host_organism_taxonids} = [];
$Canto::Track::OrganismLookup::cache = {};


($result) = $gene_manager->find_and_create_genes(\@search_genes);

is ($curs_schema->resultset('Gene')->count(), 3);

my $first_pathogen_gene = $curs_schema->resultset('Gene')->first();

my $pathogen_lookup_organism =
  $organism_lookup->lookup_by_taxonid($first_pathogen_gene->organism()->taxonid());

is ($pathogen_lookup_organism->{pathogen_or_host}, 'pathogen');

