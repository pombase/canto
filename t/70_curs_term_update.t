use strict;
use warnings;
use Test::More tests => 2;
use Test::Deep;

use Canto::TestUtil;
use Canto::CursDB;
use Canto::Curs::TermUpdate;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = Canto::TrackDB->new(config => $config);
my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

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

cmp_deeply($conditions, ['PECO:0000137', 'rich medium']);

my $term_update = Canto::Curs::TermUpdate->new(config => $config);
$term_update->update_curs_terms($curs_schema);

$conditions = _get_conditions($curs_schema);

cmp_deeply($conditions, ['PECO:0000080', 'PECO:0000137']);
