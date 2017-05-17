use strict;
use warnings;
use Test::More tests => 1;

use File::Temp qw(tempfile);

use Canto::DBUtil;

my $config = {};
my ($fh, $file_name) = tempfile();
my $schema = Canto::DBUtil::schema_for_file($config, $file_name, 'Curs');

my $storage = $schema->storage();

is ($storage->connect_info()->[0], "dbi:SQLite:dbname=$file_name");
