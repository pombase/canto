use strict;
use warnings;
use Test::More tests => 3;

use Test::MockObject;

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
  Canto::Curs::ExtensionData::as_strings($lookup, $structure);

is($extension_string,
   'exists_during(GO:0051329),requires_feature(Pfam:PF00564)|exists_during(GO:0051329)');

is(@$qualifiers, 1);
is($qualifiers->[0], 'NOT');
