use strict;
use warnings;
use Test::More tests => 2;
use Test::Deep;

use PomCur::TestUtil;
use PomCur::CursDB;
use PomCur::Curs::TermUpdate;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = PomCur::TrackDB->new(config => $config);
my $curs_schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0007');

my $curs = $track_schema->find_with_type('Curs', { curs_key => 'aaaa0007' });

sub _get_annotation_with_conditions
{
  my $curs_schema = shift;

  my $annotation_rs = $curs_schema->resultset('Annotation');

  while (defined (my $annotation = $annotation_rs->next())) {
    if (defined $annotation->data()->{conditions}) {
      return $annotation;
    }
  }
}

my $annotation = _get_annotation_with_conditions($curs_schema);
my $conditions = $annotation->data()->{conditions};

cmp_deeply(['PECO:0000137', 'rich medium'], $conditions);

my $term_update = PomCur::Curs::TermUpdate->new(config => $config);
$term_update->update_curs_terms($curs, $curs_schema);

$annotation = _get_annotation_with_conditions($curs_schema);
$conditions = $annotation->data()->{conditions};

cmp_deeply(['PECO:0000137', 'PECO:0000080'], $conditions);
