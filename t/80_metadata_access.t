use strict;
use warnings;

use PomCur::TestUtil;
use PomCur::WebUtil;
use PomCur::TrackDB;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('1_curs');

my $config = $test_util->config();
my $curs_schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0001');

package TestMetadata;

use Test::More tests => 4;
use Moose;

with 'PomCur::Role::MetadataAccess';

sub test
{
  my $self = shift;

  $self->set_metadata($curs_schema, 'key1', 'value1');
  is('value1', $self->get_metadata($curs_schema, 'key1'));

  $self->set_metadata($curs_schema, 'key1', undef);
  ok(!defined $self->get_metadata($curs_schema, 'key1'));

  $self->set_metadata($curs_schema, 'key1', 'value1');
  is('value1', $self->get_metadata($curs_schema, 'key1'));

  $self->unset_metadata($curs_schema, 'key1');
  ok(!defined $self->get_metadata($curs_schema, 'key1'));
}

1;

package main;

my $test = TestMetadata->new();

$test->test();
