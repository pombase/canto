use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

use Canto::TestUtil;
use Canto::Track::LoadUtil;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $schema = $test_util->track_schema();

my $load_util = Canto::Track::LoadUtil->new(schema => $schema);

my $dbxref = $load_util->find_dbxref("PECO:0000005");

is($dbxref->accession(), "0000005");
is($dbxref->db()->name(), "PECO");

throws_ok { $load_util->find_dbxref("no_such_id"); } qr/not in the form/;
my $no_such_id = "db:no_such_id";
throws_ok { $load_util->find_dbxref($no_such_id); } qr/no Dbxref found for $no_such_id/;
