use strict;
use warnings;
use Test::More tests => 7;
use Package::Alias Tools => 'PomCur::Controller::Tools';

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $track_schema = $test_util->track_schema();
my $config = $test_util->config();


my $db_pubmedid = 'PMID:7518718';

my ($pub, $message) =
  Tools::_load_one_pub($config, $track_schema, $db_pubmedid);

# known - in the test database
ok (defined $pub);
is ($pub->uniquename(), $db_pubmedid);
ok (!defined $message);


my $extern_pubmedid = 'PMID:18910671';

($pub, $message) =
  Tools::_load_one_pub($config, $track_schema, $extern_pubmedid);

# unknown - fetch from PubMed (or from a file in our case)
ok (defined $pub);
is ($pub->uniquename(), $extern_pubmedid);
like ($pub->title(), qr/nutritional requirements of Schizosaccharomyces pombe/);
ok (!defined $message);

