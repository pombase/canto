use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;
use File::Temp qw(tempfile);
use Data::Compare;

use PomCur::TestUtil;

{
  my $config = {};
  my $file_name = '/tmp/test_file.sqlite3';
  my $schema = PomCur::TestUtil::schema_for_file($config, $file_name, 'Curs');

  my $storage = $schema->storage();

  is ($storage->connect_info()->[0], "dbi:SQLite:dbname=$file_name");
}

{
  my $test_util = PomCur::TestUtil->new();

  ok(ref $test_util);

  throws_ok { $test_util->init_test('_no_such_config_') } qr(no test case);

}

{
  my $test_util = PomCur::TestUtil->new();

  ok(ref $test_util);

  $test_util->init_test('empty_db');

  is($test_util->track_schema()->resultset('Pub')->count(), 0);
  is($test_util->track_schema()->resultset('Gene')->count(), 0);
}

{
  my $test_util = PomCur::TestUtil->new();

  ok(ref $test_util);

  $test_util->init_test('1_curs');

  is($test_util->track_schema()->resultset('Pub')->count(), 16);
  is($test_util->track_schema()->resultset('Gene')->count(), 7);
}

{
  my $config = PomCur::Config::get_config();
  $config->merge_config($config->{test_config_file});

  my $annotations_conf =
    $config->{test_config}->{test_cases}->
        {curs_annotations_1}->[0]->{annotations}->[0];

  my ($fh, $temp_db) = tempfile();

  package MockObject;

  sub new {
    my $class = shift;
    my $table = shift;
    my $id = shift;

    return bless { table => $table, id => $id }, 'MockObject';
  }

  sub table {
    my $self = shift;
    return $self->{table}
  }

  sub gene_id {
    my $self = shift;
    return $self->{id}
  }

  sub primary_columns {
    my $self = shift;
    return $self->{table} . '_id';
  }

  package main;

  package MockCursDB;

  sub find_with_type {
    my $self = shift;
    my $class_name = shift;
    my $hash = shift;

    my $field_name = (keys %$hash)[0];
    my $field_value = $hash->{$field_name};

    my %res = (
      'Gene' => {
        primary_identifier => {
          'SPCC1739.10' => 200
        }
      }
    );

    my $obj_id = $res{$class_name}->{$field_name}->{$field_value};
    my $table = PomCur::DB::table_name_of_class($class_name);

    return MockObject->new($table, $obj_id);
  }

  package main;

  my $test_curs_db = bless {}, 'MockCursDB';

  my $results =
    PomCur::TestUtil::_process_data($test_curs_db, $annotations_conf);

  is ($results->{data}->{gene}, 200);
}
