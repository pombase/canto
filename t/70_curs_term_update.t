use strict;
use warnings;
use Test::More tests => 5;
use Test::Deep;

use Canto::TestUtil;
use Canto::CursDB;
use Canto::Curs::TermUpdate;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = Canto::TrackDB->new(config => $config);
my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

my $annotation_rs = $curs_schema->resultset('Annotation');

my $annotation = $annotation_rs->first();

my $data = $annotation->data();

$data->{term_ontid} = 'GO:123456789';   # alt_id of "GO:0055085"

$data->{extension} = [
  [
    {
      rangeValue => 'GO:0030133',
      rangeType => 'Ontology',
      relation => 'some_rel',
    },
    {
      rangeValue => 'GO:0030133',
      rangeType => 'Ontology',
      relation => 'some_rel',
      rangeDisplayName => undef,
    },
    {
      rangeValue => 'GO:0030133',
      rangeType => 'Ontology',
      relation => 'some_rel',
      rangeDisplayName => '',
    },
    {
      rangeValue => 'GO:0030133',
      rangeType => 'Ontology',
      relation => 'some_rel',
      rangeDisplayName => 'INCORRECT',
    },
    {
      rangeValue => 'GO:0030133',
      rangeType => 'Ontology',
      relation => 'some_rel',
      rangeDisplayName => 'transport vesicle',
    },
  ]
];

$annotation->data($data);
$annotation->update();


sub _get_conditions
{
  my $curs_schema = shift;

  my %ret = ();

  my $annotation_rs = $curs_schema->resultset('Annotation');

  while (defined (my $annotation = $annotation_rs->next())) {
    if (defined $annotation->data()->{conditions}) {
      for my $cond (@{$annotation->data()->{conditions}}) {
        $ret{$cond} = 1;
      }
    }
  }

  return [sort keys %ret];
}

my $conditions = _get_conditions($curs_schema);

cmp_deeply($conditions, ['FYECO:0000137', 'rich medium']);

my $term_update = Canto::Curs::TermUpdate->new(config => $config);
$term_update->update_curs_terms($curs_schema);

$conditions = _get_conditions($curs_schema);

cmp_deeply($conditions, ['FYECO:0000080', 'FYECO:0000137']);


$annotation_rs = $curs_schema->resultset('Annotation');

my $check_annotation = $annotation_rs->first();

my $check_data = $check_annotation->data();

is (@{$check_data->{extension}->[0]}, 5);

cmp_deeply($check_data->{extension}->[0],
           [
             {
               'relation' => 'some_rel',
               'rangeType' => 'Ontology',
               'rangeDisplayName' => 'transport vesicle',
               'rangeValue' => 'GO:0030133'
             },
             {
               'relation' => 'some_rel',
               'rangeType' => 'Ontology',
               'rangeValue' => 'GO:0030133',
               'rangeDisplayName' => 'transport vesicle'
             },
             {
               'rangeValue' => 'GO:0030133',
               'rangeDisplayName' => 'transport vesicle',
               'relation' => 'some_rel',
               'rangeType' => 'Ontology'
             },
             {
               'rangeValue' => 'GO:0030133',
               'rangeDisplayName' => 'transport vesicle',
               'rangeType' => 'Ontology',
               'relation' => 'some_rel'
             },
             {
               'rangeType' => 'Ontology',
               'relation' => 'some_rel',
               'rangeValue' => 'GO:0030133',
               'rangeDisplayName' => 'transport vesicle'
             }
           ]);

is($check_data->{term_ontid}, 'GO:0055085');
