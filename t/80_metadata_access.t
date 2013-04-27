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

use Test::More tests => 5;
use Data::Compare;

use Moose;

with 'PomCur::Role::MetadataAccess';

sub test_metadata
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

  my %all_metadata = $self->all_metadata($curs_schema);
  ok(Compare(\%all_metadata,
     {
       curation_pub_id => 1,
       curs_key => 'aaaa0001',
       term_suggestion_count => 0,
       unknown_conditions_count => 0,
     }));
}

1;

package main;

my $test = TestMetadata->new();

$test->test_metadata();
