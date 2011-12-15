use strict;
use warnings;
use Test::More tests => 7;

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

my $uniquename = 123456;
my $connect_string1 =
  PomCur::Curs::make_connect_string($config, $key1, $uniquename);

my ($connect_string2, $exists_flag, $key1_db_file_name) =
  PomCur::Curs::make_connect_string($config, $key1, $uniquename);

is($connect_string1, $connect_string2);

like($connect_string1, qr/$key1/);


package Test::PomCur;

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

my $test_pomcur = bless {}, 'Test::PomCur';

my $schema = PomCur::Curs::get_schema($test_pomcur);

is(ref $schema, 'PomCur::CursDB');
