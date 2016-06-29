use strict;
use warnings;
use Test::More tests => 5;

use Canto::Track::PubsLookup;
use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $lookup = Canto::Track::PubsLookup->new(config => $test_util->config());

ok(defined $lookup->schema());

my $session_data = $lookup->lookup_by_curator_email('some.testperson@pombase.org');

is(scalar(@{$session_data->{results}}), 1);

is($session_data->{count}, 1);
is($session_data->{results}->[0]->{pub_uniquename}, 'PMID:19756689');
is($session_data->{results}->[0]->{curs_key}, 'aaaa0007');
