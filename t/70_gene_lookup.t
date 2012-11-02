use strict;
use warnings;
use Test::More tests => 39;

use PomCur::Track::GeneLookup;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $lookup = PomCur::Track::GeneLookup->new(config => $test_util->config());

ok(defined $lookup->schema());

# test weird case
my $result = $lookup->lookup([qw(SPCc576.16c)]);

is(@{$result->{found}}, 1, 'look up one gene - found count');
is(@{$result->{missing}}, 0, 'look up one gene - missing count');

my $found_gene = $result->{found}->[0];
is($found_gene->{primary_identifier}, 'SPCC576.16c');
is($found_gene->{primary_name}, 'wtf22');
is($found_gene->{product}, 'wtf element Wtf22');
is($found_gene->{organism_full_name}, 'Schizosaccharomyces pombe');

$result = $lookup->lookup([qw(missing1 missing2 missing3)]);
is(@{$result->{found}}, 0, 'look up with no results - found count');
is(@{$result->{missing}}, 3, 'look up with no results - missing count');

$result = $lookup->lookup([qw(SPCC1739.10 SPNCRNA.119 missing1 missing2 missing3)]);
is(@{$result->{found}}, 2, 'look up two genes by identifier - found count');
is(@{$result->{missing}}, 3, 'look up two genes by identifier - missing count');

$result = $lookup->lookup([qw(wtf22 cdc11 missing1 missing2 missing3)]);
is(@{$result->{found}}, 2, 'look up two genes by name - found count');
is(@{$result->{missing}}, 3, 'look up two genes by name - missing count');

$result = $lookup->lookup([qw(SPCC576.16c wtf22 cdc11 missing1)]);
is(@{$result->{found}}, 2, 'look up two genes using name and identifier - found count');
is(@{$result->{missing}}, 1, 'look up two genes using name and identifier - missing count');

$result = $lookup->lookup([qw(SPCC1739.10 wtf22 cdc11 missing1 missing2 missing3)]);
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
  [qw(wtf22)]);
is(@{$result->{found}}, 1);

