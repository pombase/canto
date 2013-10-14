use strict;
use warnings;
use Test::More tests => 7;

use Canto::TestUtil;
use Canto::Curs;

my $test_util = Canto::TestUtil->new();

my $config = $test_util->config();

my $key1 = Canto::Curs::make_curs_key();
my $key2 = Canto::Curs::make_curs_key();

ok(defined $key1);
like($key1, qr/^[0-9a-f]{16}$/);

ok(defined $key2);
isnt($key1, $key2);

my $data_directory = $test_util->temp_dir();

$config->{data_directory} = $data_directory;

my $uniquename = 123456;
my $connect_string1 =
  Canto::Curs::make_connect_string($config, $key1, $uniquename);

my ($connect_string2, $exists_flag, $key1_db_file_name) =
  Canto::Curs::make_connect_string($config, $key1, $uniquename);

is($connect_string1, $connect_string2);

like($connect_string1, qr/$key1/);


package Test::Canto;

sub stash
{
  return {
    curs_key => $key1
  };
}

sub config
{
  return $config;
}


package main;

# create empty db so get_schema() succeeds
open my $key1_db, '>', $key1_db_file_name or die;
close $key1_db;

my $test_canto = bless {}, 'Test::Canto';

my $schema = Canto::Curs::get_schema($test_canto);

is(ref $schema, 'Canto::CursDB');
