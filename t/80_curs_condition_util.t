use strict;
use warnings;
use Test::More tests => 2;
use Test::Deep;

use Canto::TestUtil;
use Canto::Track;
use Canto::Curs::ConditionUtil;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();

my $lookup = Canto::Track::get_adaptor($config, 'ontology');

my @conds = ('PECO:0000006', 'some free text');
my @conds_with_names =
  Canto::Curs::ConditionUtil::get_conditions_with_names($lookup, \@conds);

my @expected_conditions = (
  {
    'name' => 'low temperature',
    'term_id' => 'PECO:0000006'
  },
  {
    'name' => 'some free text'
  }
);

cmp_deeply(\@conds_with_names,
           [
             @expected_conditions
           ]);

my @cond_names = ('low temperature', 'some free text');

my @conds_with_ids =
  Canto::Curs::ConditionUtil::get_conditions_from_names($lookup, \@cond_names);

cmp_deeply(\@conds_with_ids,
           [
             @expected_conditions
           ]);
