use strict;
use warnings;
use Test::More tests => 36;

use PomCur::Chado::GeneLookup;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $lookup = PomCur::Chado::GeneLookup->new(config => $test_util->config());

ok(defined $lookup->schema());

# test weird case
my $result = $lookup->lookup([qw(SPBC12C2.02c)]);

is(@{$result->{found}}, 1, 'look up one gene - found count');
is(@{$result->{missing}}, 0, 'look up one gene - missing count');

my $found_gene = $result->{found}->[0];
is($found_gene->{primary_identifier}, 'SPBC12C2.02c');
is($found_gene->{primary_name}, 'ste20');
is($found_gene->{product}, 'Rictor homolog, Ste20');
is($found_gene->{organism_full_name}, 'Schizosaccharomyces pombe');

$result = $lookup->lookup([qw(missing1 missing2 missing3)]);
is(@{$result->{found}}, 0, 'look up with no results - found count');
is(@{$result->{missing}}, 3, 'look up with no results - missing count');

$result = $lookup->lookup([qw(SPBC12C2.02c missing1 missing2 missing3)]);
is(@{$result->{found}}, 1, 'look up by identifier - found count');
is(@{$result->{missing}}, 3, 'look up two genes by identifier - missing count');

# test returning synonyms
$result = $lookup->lookup([qw(ste20-synonym)]);
is(@{$result->{found}}, 1);
is(@{$result->{found}->[0]->{synonyms}}, 2);
my @synonyms = sort @{$result->{found}->[0]->{synonyms}};
is ($synonyms[0], 'SPBC12C2.02c');
is ($synonyms[1], 'ste20-synonyms');

