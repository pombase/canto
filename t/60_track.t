use strict;
use warnings;
use Test::More tests => 18;
use Test::Deep;

use PomCur::TestUtil;
use PomCur::Track;
use PomCur::TrackDB;
use PomCur::DBUtil;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my @results = $schema->resultset('Curs')->search();

is(@results, 2);

my $key = 'abcd0123';

my $first_contact_email = 'val@sanger.ac.uk';

my $pub = $schema->find_with_type('Pub', { uniquename => 'PMID:19056896' });

is($pub->type()->name(), 'unknown');

my $person = $schema->find_with_type('Person',
                                     {
                                       email_address => $first_contact_email
                                     });

my $curs = $schema->create_with_type('Curs',
                                     {
                                       pub => $pub,
                                       assigned_curator => $person,
                                       curs_key => $key,
                                     });


my $data_directory = $config->{data_directory};

my @existing_files = glob("$data_directory/*.sqlite3");

is(@existing_files, 3);
ok(grep { $_ eq "$data_directory/track.sqlite3" } @existing_files);

PomCur::Track::create_curs_db($config, $curs);

@results = $schema->resultset('Curs')->search();

is(@results, 3);


my @files_after = sort glob("$data_directory/*.sqlite3");
is(@files_after, 4);

my $new_curs_db = "$data_directory/curs_$key.sqlite3";

cmp_deeply([@files_after],
           [
             "$data_directory/curs_aaaa0006.sqlite3",
             "$data_directory/curs_aaaa0007.sqlite3",
             $new_curs_db,
             "$data_directory/track.sqlite3"
           ]);

my $curs_schema =
  PomCur::DBUtil::schema_for_file($config, $new_curs_db, 'Curs');

# make sure it's a valid sqlite3 database
my $curs_metadata_rs = $curs_schema->resultset('Metadata');

my %metadata_hash = ();

while (defined (my $metadata = $curs_metadata_rs->next())) {
  $metadata_hash{$metadata->key()} = $metadata->value();
}

is($metadata_hash{first_contact_email}, $first_contact_email);
is($metadata_hash{curs_key}, $curs->curs_key());

my $curs_db_pub_id = $metadata_hash{curation_pub_id};
my $curs_db_pub = $curs_schema->find_with_type('Pub', $curs_db_pub_id);

is($curs_db_pub->uniquename(), $pub->uniquename());
is($curs_db_pub->abstract(), $pub->abstract());

my $track_schema = $test_util->track_schema();
my $cursdb_iter = PomCur::Track::curs_iterator($config, $track_schema);

my $cursdb_count = 0;

while (my ($curs, $cursdb) = $cursdb_iter->()) {
  $cursdb_count++;
  is(ref $cursdb, 'PomCur::CursDB');

  my $metadata_curs_key =
    $cursdb->resultset('Metadata')->find({ key => 'curs_key' });
  ok($curs->curs_key() eq $metadata_curs_key->value());

  fail("too many cursdbs"), last if $cursdb_count > 100;
}

is ($cursdb_count, 3);
