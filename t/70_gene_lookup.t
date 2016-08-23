use strict;
use warnings;
use Test::More tests => 44;

use Try::Tiny;

use Canto::Track::GeneLookup;

use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $lookup = Canto::Track::GeneLookup->new(config => $test_util->config());

ok(defined $lookup->schema());

# test weird case
my $result = $lookup->lookup([qw(SPbC1826.01c)]);

is(@{$result->{found}}, 1, 'look up one gene - found count');
is(@{$result->{missing}}, 0, 'look up one gene - missing count');

my $found_gene = $result->{found}->[0];
is($found_gene->{primary_identifier}, 'SPBC1826.01c');
is($found_gene->{primary_name}, 'mot1');
is($found_gene->{product}, 'TATA-binding protein associated factor Mot1 (predicted)');
is($found_gene->{organism_full_name}, 'Schizosaccharomyces pombe');

$result = $lookup->lookup([qw(missing1 missing2 missing3)]);
is(@{$result->{found}}, 0, 'look up with no results - found count');
is(@{$result->{missing}}, 3, 'look up with no results - missing count');

$result = $lookup->lookup([qw(SPCC1739.10 SPNCRNA.119 missing1 missing2 missing3)]);
is(@{$result->{found}}, 3, 'look up two genes by identifier - found count');
is(@{$result->{missing}}, 3, 'look up two genes by identifier - missing count');

# check an identifier that is a primary_identifier and a synonym
$result = $lookup->lookup([qw(SPCC1739.10)]);
is(@{$result->{found}}, 2, 'look up two genes by identifier - found count');
is(@{$result->{missing}}, 0, 'look up two genes by identifier - missing count');

$result = $lookup->lookup([qw(mot1 cdc11 missing1 missing2 missing3)]);
is(@{$result->{found}}, 2, 'look up two genes by name - found count');
is(@{$result->{missing}}, 3, 'look up two genes by name - missing count');

$result = $lookup->lookup([qw(SPBC1826.01c mot1 cdc11 missing1)]);
is(@{$result->{found}}, 2, 'look up two genes using name and identifier - found count');
is(@{$result->{missing}}, 1, 'look up two genes using name and identifier - missing count');

$result = $lookup->lookup([qw(SPCC1739.10 mot1 cdc11 missing1 missing2 missing3)]);
is(@{$result->{found}}, 3, 'look up two genes by name and identifier - found count');
is(@{$result->{missing}}, 3, 'look up two genes by name and identifier - missing count');

# test search for a name and identifier that match the same gene
$result = $lookup->lookup([qw(SPCC1739.11c cdc11 missing1)]);
is(@{$result->{found}}, 1);
is(@{$result->{missing}}, 1);

# test returning synonyms
$result = $lookup->lookup([qw(SPAC3A11.14c)]);
is(@{$result->{found}}, 1);
is(@{$result->{found}->[0]->{synonyms}}, 2);
my @synonyms = sort @{$result->{found}->[0]->{synonyms}};
is ($synonyms[0], 'SPAC3H5.03c');
is ($synonyms[1], 'klp1');

# test searching for a synonym that matches two genes
$result = $lookup->lookup([qw(rpn5)]);
is(@{$result->{found}}, 2);
my @genes = sort {
  $a->{primary_identifier} cmp $b->{primary_identifier}
} @{$result->{found}};
is ($genes[0]->{primary_identifier}, 'SPAC1420.03');
is ($genes[1]->{primary_identifier}, 'SPAPB8E5.02c');

# test searching for a synonym of one gene that is the primary_name of another
$result = $lookup->lookup([qw(ssm4)]);
is(@{$result->{found}}, 2);
@genes = sort {
  $a->{primary_identifier} cmp $b->{primary_identifier}
} @{$result->{found}};

is ($genes[0]->{match_types}->{primary_name}, 'ssm4');
is ($genes[0]->{primary_name}, 'ssm4');
is ($genes[1]->{match_types}->{synonym}->[0], 'ssm4');
is ($genes[1]->{primary_name}, 'doa10');

# test searching for 3 identifiers that all match primary_name,
# primary_identifier and a synonym of the same gene
$result = $lookup->lookup([qw(SPAC3A11.14c pkl1 klp1)]);
is(@{$result->{found}}, 1);
my $gene = $result->{found}->[0];

is ($gene->{match_types}->{primary_name}, 'pkl1');
is ($gene->{match_types}->{primary_identifier}, 'SPAC3A11.14c');
is ($gene->{match_types}->{synonym}->[0], 'klp1');
is ($gene->{primary_name}, 'pkl1');


# S. cerevisiae lookup
$result = $lookup->lookup([qw(ssf1)]);
is(@{$result->{found}}, 1);

# test constraining by organism
$result = $lookup->lookup(
  {
    search_organism => {
      genus => 'Schizosaccharomyces',
      species => 'pombe',
    },
  },
  [qw(ssf1)]);
is(@{$result->{found}}, 0);

$result = $lookup->lookup(
  {
    search_organism => {
      genus => 'Schizosaccharomyces',
      species => 'pombe',
    },
  },
  [qw(mot1)]);
is(@{$result->{found}}, 1);


# test that we get a failure if there is no taxon_id organismprop
my $track_schema = $test_util->track_schema();

my $organismprop_rs = $track_schema->resultset('Organismprop');
$organismprop_rs
  ->search({'type.name' => 'taxon_id' },
           { join => 'type' })->delete();

$lookup->cache()->clear();

# test that the taxon ID cache works
$result = $lookup->lookup(
  {
    search_organism => {
      genus => 'Schizosaccharomyces',
      species => 'pombe',
    },
  },
  [qw(klp1)]);
is(@{$result->{found}}, 1);

$lookup->{_taxonid_cache} = {};
$lookup->cache()->clear();

# should fail because taxon ID not found
try {
  $result = $lookup->lookup(
    {
      search_organism => {
        genus => 'Schizosaccharomyces',
        species => 'pombe',
      },
    },
    [qw(klp1)]);
  fail("lookup() should have failed");
} catch {
  like ($_, qr/no 'organism_taxon_id' configuration found and no 'taxon_id' organismprop found/);
};

# set the taxon config - needed when the taxon ID isn't in Chado
$test_util->config()->{organism_taxon_id}->{Schizosaccharomyces}->{pombe} = 4896;
$result = $lookup->lookup(
  {
    search_organism => {
      genus => 'Schizosaccharomyces',
      species => 'pombe',
    },
  },
  [qw(klp1)]);

is(@{$result->{found}}, 1);
