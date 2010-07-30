use strict;
use warnings;
use Test::More tests => 6;

use PomCur::TestUtil;
use PomCur::Curs;

my $test_util = PomCur::TestUtil->new();

my $config = $test_util->config();

my $key1 = PomCur::Curs::make_curs_key();
my $key2 = PomCur::Curs::make_curs_key();

ok(defined $key1);

like($key1, qr/^[0-9a-f]{16}$/);

ok(defined $key2);

isnt($key1, $key2);

 my $data_directory = $test_util->temp_dir();

$config->{data_directory} = $data_directory;

my $pubmedid = 123456;
my $connect_string1 =
  PomCur::Curs::make_connect_string($config, $key1, $pubmedid);

my ($connect_string2, $exists_flag) =
  PomCur::Curs::make_connect_string($config, $key1, $pubmedid);

is($connect_string1, $connect_string2);

like($connect_string1, qr/$key1/);
