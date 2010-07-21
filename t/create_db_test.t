use strict;
use warnings;
use Test::More tests => 2;

BEGIN { use_ok "TestUtil"; }

use TestUtil;

my $config = TestUtil::config();

my $sqlite_connect_info = $config->{"Model::TrackModel"}->{connect_info}->[0];

(my $sqlite_db_file_name = $sqlite_connect_info) =~ s/dbi:SQLite:dbname=(.*)/$1/;

# make sure the database has something in it
open my $pipe, "sqlite3 $sqlite_db_file_name 'select count(*) from person'|" or die;
my $select_result = <$pipe>;
chomp $select_result;
close $pipe;

is($select_result, "1");

