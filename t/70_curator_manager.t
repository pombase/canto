use strict;
use warnings;
use Test::More tests => 11;

use PomCur::TestUtil;
use PomCur::TrackDB;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('curs_annotations_2');
my $config = $test_util->config();

my $track_schema = PomCur::TrackDB->new(config => $config);

my $curator_manager = PomCur::Track::CuratorManager->new(config => $config);

my $curs_curator_rs = $track_schema->resultset('CursCurator');
is($curs_curator_rs->count(), 2);

sub _get_test_row
{
  return
    $curs_curator_rs->search({ 'curs.curs_key' => 'aaaa0007' },
                             { join => 'curs',
                               order_by => { -desc => 'curs_curator_id' } })->first();
}

my $session_aaaa0007_row = _get_test_row();

is ($session_aaaa0007_row->curator()->email_address(), 'some.testperson@pombase.org');

my ($email, $name, $accepted_date) = $curator_manager->current_curator('aaaa0007');
is ($email, 'some.testperson@pombase.org');
is ($name, 'Some Testperson');
ok (!defined $accepted_date);

$curator_manager->set_curator('aaaa0007', 'val@sanger.ac.uk');
is($curs_curator_rs->count(), 3);

$session_aaaa0007_row = _get_test_row();
is ($session_aaaa0007_row->curator()->email_address(), 'val@sanger.ac.uk');

$session_aaaa0007_row = _get_test_row();
ok (!defined $session_aaaa0007_row->accepted_date());

$curator_manager->accept_session('aaaa0007');

$session_aaaa0007_row = _get_test_row();
ok (defined $session_aaaa0007_row->accepted_date());
like ($session_aaaa0007_row->accepted_date(), qr/^2\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$/);
is($curs_curator_rs->count(), 3);
