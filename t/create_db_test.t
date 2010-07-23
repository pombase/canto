use strict;
use warnings;
use Test::More tests => 2;

BEGIN { use_ok "PomCur::TestUtil"; }

use PomCur::TestUtil;

my $db_file_name = PomCur::TestUtil::track_db_file_name();

# make sure the database has something in it
open my $pipe, "sqlite3 $db_file_name 'select count(*) from person'|" or die;
my $select_result = <$pipe>;
chomp $select_result;
close $pipe;

is($select_result, "17");

