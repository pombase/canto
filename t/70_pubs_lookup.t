use strict;
use warnings;
use Test::More tests => 8;
use Test::Deep;

use Canto::Track::PubsLookup;
use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $lookup = Canto::Track::PubsLookup->new(config => $test_util->config());

ok(defined $lookup->schema());

my $missing_pub = $lookup->lookup_by_uniquename('PMID:99999999');
ok (!defined $missing_pub);

my $pub_detail = $lookup->lookup_by_uniquename('PMID:19056896');

cmp_deeply($pub_detail,
          {
            'authors' => "Helmlinger D, Marguerat S, Vill\x{e9}n J, Gygi SP, B\x{e4}hler J, Winston F",
            'uniquename' => 'PMID:19056896',
            'publication_date' => '2008 11 15',
            'title' => 'The S. pombe SAGA complex controls the switch from proliferation to sexual differentiation through the opposing roles of its subunits Gcn5 and Spt8.',
            'citation' => 'Genes Dev. 2008 Nov 15;22(22):3184-95'
          });


my $session_data = $lookup->lookup_by_curator_email('some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org');

is(scalar(@{$session_data->{results}}), 1);

is($session_data->{count}, 1);
my $result_row = $session_data->{results}->[0];
is($result_row->{pub_uniquename}, 'PMID:19756689');
is($result_row->{curs_key}, 'aaaa0007');
is($result_row->{status}, 'CURATION_IN_PROGRESS');
