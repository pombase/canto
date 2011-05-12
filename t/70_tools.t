use strict;
use warnings;
use Test::More tests => 8;
use Package::Alias Tools => 'PomCur::Controller::Tools';
use LWP::Protocol::PSGI;

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
