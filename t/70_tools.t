use strict;
use warnings;
use Test::More tests => 13;
use Package::Alias Tools => 'PomCur::Controller::Tools';
use LWP::Protocol::PSGI;
use Plack::Test;
use HTTP::Request;
use JSON;
use POSIX qw/strftime/;

use PomCur::TestUtil;
use PomCur::Curs::State qw/:all/;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $track_schema = $test_util->track_schema();
my $config = $test_util->config();


my $db_pubmedid = 'PMID:7518718';

my ($pub, $message) =
  Tools::_load_one_pub($config, $track_schema, $db_pubmedid);

# known - in the test database
ok (defined $pub);
is ($pub->uniquename(), $db_pubmedid);
ok (!defined $message);


my $pubmed_18910671_filename = $config->{test_config}->{test_extra_publication};
my $pubmed_18910671_xml_path =
  $test_util->test_data_dir_full_path($pubmed_18910671_filename);
my $pubmed_18910671_fh = new IO::File $pubmed_18910671_xml_path, "r";

my $app = sub {
  local $/ = undef;
  my $env = shift;
  return [
    200,
    ['Content-Type' => 'text/plain'],
    $pubmed_18910671_fh,
  ];
};

# avoid accessing the pubmed server, fake it:
LWP::Protocol::PSGI->register($app);

my $extern_pubmedid = 'PMID:18910671';

($pub, $message) =
  Tools::_load_one_pub($config, $track_schema, $extern_pubmedid);

# unknown - fetch from PubMed (or from a file in our case)
ok (defined $pub);
is ($pub->uniquename(), $extern_pubmedid);
like ($pub->title(), qr/nutritional requirements of Schizosaccharomyces pombe/);
ok (!defined $message);

# make sure it's in the database
my $db_pub = $track_schema->find_with_type('Pub',
                                           {
                                             uniquename => $extern_pubmedid
                                           });

is ($db_pub->uniquename(), $extern_pubmedid);

my $curs_schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0007');
my $admin_person = $test_util->get_a_person($track_schema, 'admin');
my $state = PomCur::Curs::State->new(config => $config);

$state->set_state($curs_schema, APPROVAL_IN_PROGRESS,
                  { force => CURATION_IN_PROGRESS,
                    current_user => $admin_person });

$state->set_state($curs_schema, APPROVED,
                  { force => APPROVAL_IN_PROGRESS,
                    current_user => $admin_person });

sub do_export_approved {
  my $app = $test_util->plack_app()->{app};
  my $cookie_jar = $test_util->cookie_jar();

  my $content;

  test_psgi $app, sub {
    my $cb = shift;

    $test_util->app_login($cookie_jar, $cb);

    my $url = "http://localhost:5000/tools/export/approved/json";
    my $req = HTTP::Request->new(GET => $url);
    $cookie_jar->add_cookie_header($req);
    my $res = $cb->($req);

    $content = $res->content();
  };

  return $content;
}

my $content_1 = do_export_approved();
my $content_1_parsed = decode_json($content_1);
is (keys %{$content_1_parsed->{curation_sessions}}, 1);

# slight anomaly, the status is the pre-export status
is ($content_1_parsed->{curation_sessions}->{aaaa0007}->{annotation_status}, 'APPROVED');

my $content_2 = do_export_approved();
my $content_2_parsed = decode_json($content_2);
# should be no results as the sessions are already exported
is (keys %{$content_2_parsed->{curation_sessions}}, 0);



my $aaaa0006_schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0006');
$state->set_state($aaaa0006_schema, NEEDS_APPROVAL);

my $pmid = 'PMID:19756689';
my ($new_curs, $new_curs_db) = PomCur::Track::create_curs($config, $track_schema, $pmid);
my $new_curs_key = $new_curs->curs_key();

my $created_date =
  $state->get_metadata($new_curs_db, PomCur::Curs::State::SESSION_CREATED_TIMESTAMP_KEY);

(my $test_date = $created_date) =~ s/^(\d\d\d\d-\d\d-\d\d)\s.*/$1/;

my $app_prefix = 'http://localhost';

my $daily_summary_text =
  PomCur::Controller::Tools::_daily_summary_text($config, $test_date, $app_prefix);

like($daily_summary_text, qr/activity for $test_date/);
like($daily_summary_text, qr|not yet accepted\s+$app_prefix/curs/$new_curs_key\s+$pmid\s+"SUMOylation is required for normal|);
