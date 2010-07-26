use strict;
use warnings;
use Test::More tests => 1;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

my $db_file_name = $test_util->track_db_file_name();

# make sure the database has something in it
open my $pipe, "sqlite3 $db_file_name 'select count(*) from person'|" or die;
my $select_result = <$pipe>;
chomp $select_result;
close $pipe;

is($select_result, 18);

