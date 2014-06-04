use strict;
use warnings;
use Test::More tests => 4;

use File::Temp qw(tempfile);

use Canto::DBUtil;

{
  my $config = {};
  my ($fh, $file_name) = tempfile();
  my $schema = Canto::DBUtil::schema_for_file($config, $file_name, 'Curs');

  my $storage = $schema->storage();

  is ($storage->connect_info()->[0], "dbi:SQLite:dbname=$file_name");
}

my ($fh, $temp_file_name) = tempfile();

my $test_db = DBI->connect("dbi:SQLite:$temp_file_name");

$test_db->do("CREATE TABLE test1 (col1 text, col2 integer)");

$test_db->do("INSERT INTO test1 (col1, col2) values ('some_text', 42)");

my ($new_fh, $new_temp_file_name) = tempfile();

my $new_test_db = DBI->connect("dbi:SQLite:$new_temp_file_name");

Canto::DBUtil::copy_sqlite_database($test_db, $new_test_db);

$test_db->do("INSERT INTO test1 (col1, col2) values ('new_text', 100)");

my $sth = $new_test_db->prepare('select col1, col2 from test1');
$sth->execute();
my $res = $sth->fetchall_arrayref();

is (@$res, 1);
is ($res->[0]->[0], 'some_text');
is ($res->[0]->[1], 42);
