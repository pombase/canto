use strict;
use warnings;
use Test::More tests => 21;

use Canto::TestUtil;
use Canto::TrackDB;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');
my $config = $test_util->config();

my $track_schema = Canto::TrackDB->new(config => $config);

my $curator_manager = Canto::Track::CuratorManager->new(config => $config);

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

is ($session_aaaa0007_row->curator()->email_address(), 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org');

my ($email, $name, $known_as, $accepted_date, $community_curated, $creation_date) =
  $curator_manager->current_curator('aaaa0007');
is ($email, 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org');
is ($name, 'Some Testperson');
ok (defined $accepted_date);
ok ($community_curated);
like ($creation_date, qr/^\d\d\d\d-\d\d-\d\d/);

$session_aaaa0007_row->accepted_date(undef);
$session_aaaa0007_row->update();

($email, $name, $known_as, $accepted_date) = $curator_manager->current_curator('aaaa0007');
is ($email, 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org');
is ($name, 'Some Testperson');
ok (!defined $accepted_date);

$curator_manager->set_curator('aaaa0007', 'val@3afaba8a00c4465102939a63e03e2fecba9a4dd7.ac.uk');
is($curs_curator_rs->count(), 3);

$session_aaaa0007_row = _get_test_row();
is ($session_aaaa0007_row->curator()->email_address(), 'val@3afaba8a00c4465102939a63e03e2fecba9a4dd7.ac.uk');

$session_aaaa0007_row = _get_test_row();
ok (!defined $session_aaaa0007_row->accepted_date());

$curator_manager->accept_session('aaaa0007');

$session_aaaa0007_row = _get_test_row();
ok (defined $session_aaaa0007_row->accepted_date());
like ($session_aaaa0007_row->accepted_date(), qr/^2\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$/);
is($curs_curator_rs->count(), 3);

my @all_curators = $curator_manager->session_curators('aaaa0007');

is($all_curators[0]->[0], 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org');
is($all_curators[1]->[0], 'val@3afaba8a00c4465102939a63e03e2fecba9a4dd7.ac.uk');


my $sessions_by_curator_email_rs =
  $curator_manager->sessions_by_curator_email('val@3afaba8a00c4465102939a63e03e2fecba9a4dd7.ac.uk');

is($sessions_by_curator_email_rs->count(), 1);
my $curs_by_email = $sessions_by_curator_email_rs->first();
is($curs_by_email->curs_key(), 'aaaa0007');
is($curs_by_email->pub()->uniquename(), 'PMID:19756689');
