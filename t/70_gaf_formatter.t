use strict;
use warnings;
use Test::More tests => 17;
use MooseX::Test::Role;
use IO::String;

use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();

my @curs_objects = $track_schema->resultset('Curs')
      ->search({ curs_key => 'aaaa0007' })->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $mock_formatter = consumer_of('Canto::Role::GAFFormatter');

{
  my $zip_data = $mock_formatter->get_curs_annotation_zip($config, $curs_schema);
  my $zip_io = IO::String->new($zip_data);
  my $zip = Archive::Zip->new();

  $zip->readFromFileHandle($zip_io);

  my %expected_filenames = (
    'phenotype.tsv' => 1,
    'molecular_function.tsv' => 1,
    'biological_process.tsv' => 1,
  );

  for my $member ($zip->members) {
    delete $expected_filenames{$member->fileName()};

    my $file_io = IO::String->new();

    $member->extractToFileHandle($file_io);

    # a poor check, just confirms that there is some content:
    like(${$file_io->string_ref()}, qr/\t.*\t/, 'checking: ' . $member->fileName());
  }

  is(keys %expected_filenames, 0);
}

# test getting all annotation
{
  my $curs_resultset = $track_schema->resultset('Curs');
  my $zip_data = $mock_formatter->get_all_curs_annotation_zip($config, $curs_resultset);

  my $zip_io = IO::String->new($zip_data);
  my $zip = Archive::Zip->new();

  $zip->readFromFileHandle($zip_io);

  my %expected_filenames = (
    'phenotype.tsv' => 2,
    'cellular_component.tsv' => 0,
    'molecular_function.tsv' => 1,
    'biological_process.tsv' => 3,
    'post_translational_modification.tsv' => 0,
    'physical_interaction.tsv' => 0,
    'genetic_interaction.tsv' => 0,
  );

  my $member_count = 0;

  for my $member ($zip->members()) {
    $member_count++;
    my $expected_line_count;

    if (exists $expected_filenames{$member->fileName()}) {
      $expected_line_count = delete $expected_filenames{$member->fileName()};
    } else {
      fail "unexpected member: " . $member->fileName();
    }

    my $file_io = IO::String->new();
    $member->extractToFileHandle($file_io);
    my $member_contents = ${$file_io->string_ref()};

    if ($expected_line_count > 0) {
      # a poor check, just confirms that there is some content:
      like($member_contents, qr/\t.*\t/);
      is($member_contents =~ tr/\n//, $expected_line_count);
    } else {
      ok(length $member_contents == 0);
    }
  }

  is(keys %expected_filenames, 0);

  is($member_count, 7);
}
