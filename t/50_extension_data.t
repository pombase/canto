use strict;
use warnings;
use Test::More tests => 1;

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
  ],
  [
    {
      relation => 'exists_during',
      rangeValue => 'GO:0051329',
    },
  ],
];

my $extension_obj =
  Canto::Curs::ExtensionData->new(structure => $structure);

is($extension_obj->as_string(),
   'exists_during(GO:0051329),requires_feature(Pfam:PF00564)|exists_during(GO:0051329)');
