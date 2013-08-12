use strict;
use warnings;
use Test::More tests => 14;

use Test::MockObject;

use PomCur::TestUtil;
use PomCur::EmailUtil;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $config = $test_util->config();

my $mock = Test::MockObject->new();
$mock->mock('config', sub { return $config; });
$mock->mock('_process_template', sub { PomCur::EmailUtil::_process_template(@_); });

my $curs_key = "aaaa0007";
my $root_url = "http://localhost:5000/curs/$curs_key";
my $pub_id = "PMID:10467002";
my $pub_title = "A clever paper";
my $help_url = "http://localhost:5000/docs/";
my $curator_name = "Val Wood";
my $curator_email = 'val@example.com';

my $person_name = 'Logged In Person';
my $person_email = 'mock_email@example.com';

my $mock_person = Test::MockObject->new();
$mock_person->mock('name', sub { return $person_name; });
$mock_person->mock('email_address', sub { return $person_email; });

my %args = (
  session_link => $root_url,
  publication_uniquename => $pub_id,
  publication_title => $pub_title,
  curator_name => $curator_name,
  curator_email => $curator_email,
  help_index => $help_url,
  logged_in_user => $mock_person,
);

my $default_test_from = 'test_from@example.org';

$config->{email}->{from_address} = $default_test_from;
$config->{email}->{templates}->{session_assigned}->{body} =
  "email_templates/pombase/session_assigned_body.mhtml";

my ($subject, $body, $from) =
  PomCur::EmailUtil::make_email($mock, 'session_assigned', %args);

ok ($from ne $default_test_from);
is ($from, $person_email);

like ($subject, qr/publication has been assigned to you/);

ok ($body =~ /Dear $curator_name/);
ok ($body =~ /PMID:10467002/);
ok ($body =~ /"A clever paper"/);
ok ($body =~ /$root_url/);
ok ($body =~ /several previously curated annotations/);
ok ($body =~ /$person_name/);

$args{recipient_name} = "Test Name";
$args{recipient_email} = 'test@example.com';
$args{reassigner_name} = "Test Name";
$args{reassigner_email} = 'test@example.com';

($subject, $body, $from) =
  PomCur::EmailUtil::make_email($mock, 'reassigner', %args);

like ($body, qr/Thank you for reassigning/);
like ($body, qr/Below is a copy/);
like ($body, qr/Dear Val Wood/);
like ($body, qr/Test Name <test\@example.com> has invited/);

is ($from, $default_test_from);
