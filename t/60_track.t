use strict;
use warnings;
use Test::More tests => 12;

use PomCur::TestUtil;
use PomCur::Track;
use PomCur::TrackDB;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @results = $schema->resultset('Curs')->search();

is(@results, 0);

my $key = 'abcd0123';

my $first_contact_email = 'val@sanger.ac.uk';

my $pub = $schema->find_with_type('Pub', { pubmedid => '19056896' });

is($pub->type()->name(), 'unknown');

my $person = $schema->find_with_type('Person',
                                     {
                                       networkaddress => $first_contact_email
                                     });

my $curs = $schema->create_with_type('Curs',
                                     {
                                       pub => $pub,
                                       community_curator => $person,
                                       curs_key => $key,
                                     });


my $data_directory = $config->{data_directory};

my @existing_files = glob("$data_directory/*.sqlite3");

is(@existing_files, 1);
is($existing_files[0], "$data_directory/track.sqlite3");

PomCur::Track::create_curs_db($config, $curs);

@results = $schema->resultset('Curs')->search();

is(@results, 1);


my @files_after = sort glob("$data_directory/*.sqlite3");
is(@files_after, 2);

my $new_curs_db = "$data_directory/curs_$key.sqlite3";

is($files_after[0], $new_curs_db);
is($files_after[1], "$data_directory/track.sqlite3");

my $curs_schema =
  PomCur::TestUtil::schema_for_file($config, $new_curs_db, 'Curs');

# make sure it's a valid sqlite3 database
my $curs_metadata_rs = $curs_schema->resultset('Metadata');

my %metadata_hash = ();

while (defined (my $metadata = $curs_metadata_rs->next())) {
  $metadata_hash{$metadata->key()} = $metadata->value();
}

is($metadata_hash{first_contact_email}, $first_contact_email);
is($metadata_hash{curs_id}, $curs->curs_id());

my $curs_db_pub_id = $metadata_hash{curation_pub_id};
my $curs_db_pub = $curs_schema->find_with_type('Pub', $curs_db_pub_id);

is($curs_db_pub->pubmedid(), $pub->pubmedid());
is($curs_db_pub->abstract(), $pub->abstract());
