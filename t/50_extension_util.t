use strict;
use warnings;
use Test::More tests => 3;
use Test::Deep;

use Try::Tiny;

use Canto::ExtensionUtil;

my @res = Canto::ExtensionUtil::parse_extension("rel1 ( range1) ,\nrel2(range2)|rel3(range3)\n");

cmp_deeply([@res],
           [
             [
               {
                 'relation' => 'rel1',
                 'rangeValue' => 'range1'
               },
               {
                 'relation' => 'rel2',
                 'rangeValue' => 'range2'
               }
             ],
             [
               {
                 'rangeValue' => 'range3',
                 'relation' => 'rel3'
               }
             ]
           ]);

@res = Canto::ExtensionUtil::parse_extension("rel1(range1),residue=10");
cmp_deeply([@res],
           [
             [
               {
                 'relation' => 'rel1',
                 'rangeValue' => 'range1'
               },
               {
                 'rangeValue' => '10',
                 'relation' => 'residue'
               }
             ]
           ]);

try {
  @res = Canto::ExtensionUtil::parse_extension("rel1(range1),qualifier=NOT");
  fail("parse should fail");
} catch {
  is($_, "upgrade script can't handle: qualifier=NOT\n");
};

