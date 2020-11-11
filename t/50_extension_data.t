use strict;
use warnings;
use Test::More tests => 3;

use Test::MockObject;

use Canto::TestUtil;
use Canto::Curs::Utils;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');


my $lookup = Test::MockObject->new();

$lookup->mock('lookup_by_id',
            sub {
              my ($self, %args) = @_;
              if ($args{id} eq 'PBHQ:002') {
                return { name => 'NOT' }
              } else {
                die;
              }
            });

use Canto::Curs::ExtensionData;

my $structure = [
  [
    {
      relation => 'exists_during',
      rangeValue => 'GO:0051329',
    },
    {
      relation => 'requires_feature',
      rangeValue => 'Pfam:PF00564',
    },
    {
      relation => 'has_qualifier',
      rangeValue => 'PBHQ:002',
    },
    {
      relation => 'has_input',
      rangeValue => 'SPBC1826.01c',
    }
  ],
  [
    {
      relation => 'exists_during',
      rangeValue => 'GO:0051329',
    },
  ],
];

my ($extension_string, $qualifiers) =
  Canto::Curs::ExtensionData::as_strings($lookup, $curs_schema, 'PomBase', $structure);

is($extension_string,
   'exists_during(GO:0051329),requires_feature(Pfam:PF00564),has_input(PomBase:SPBC1826.01c)|exists_during(GO:0051329)');

is(@$qualifiers, 1);
is($qualifiers->[0], 'NOT');
