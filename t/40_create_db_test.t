use strict;
use warnings;
use Test::More tests => 1;

use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();
my %results = $test_util->init_test();

my $db_file_name = $results{track_db_file_name};

my $schema = $test_util->track_schema();

# make sure the database has something in it
my $person_count = $schema->resultset('Person')->count();

ok($person_count > 10);
