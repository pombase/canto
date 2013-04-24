use strict;
use warnings;
use Test::More tests => 4;
use MooseX::Test::Role;

use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('curs_annotations_1');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();

my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();
my $curs_schema = PomCur::Curs::get_schema_for_key($config, $curs_key);

my $mock_formatter = consumer_of('PomCur::Role::GAFFormatter');
my $zip_data = $mock_formatter->get_curs_annotation_zip($config, $curs_schema);

use IO::String;

my $zip_io = IO::String->new($zip_data);

my $zip = Archive::Zip->new();

$zip->readFromFileHandle($zip_io);

my %expected_filenames = (
  'cellular_component.tsv' => 1,
  'biological_process.tsv' => 1,
);

for my $member ($zip->members) {
  delete $expected_filenames{$member->fileName()};

  my $file_io = IO::String->new();

  $member->extractToFileHandle($file_io);

  # a poor check, just confirms that there is some content:
  like(${$file_io->string_ref()}, qr/\t.*\t/);
}

is(keys %expected_filenames, 0);
