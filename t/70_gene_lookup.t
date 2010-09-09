use strict;
use warnings;
use Test::More tests => 15;

use PomCur::Track::GeneLookup;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $lookup = PomCur::Track::GeneLookup->new(config => $test_util->config());

ok(defined $lookup->schema());

my $result = $lookup->lookup([qw(SPCC576.16c)]);

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

$result = $lookup->lookup([qw(SPCC1739.10 wtf22 cdc11 missing1 missing2 missing3)]);
is(@{$result->{found}}, 3, 'look up two genes by name and identifier - found count');
is(@{$result->{missing}}, 3, 'look up two genes by name and identifier - missing count');

