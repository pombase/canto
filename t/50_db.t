use strict;
use warnings;
use Test::More tests => 4;

use PomCur::DB;
use PomCur::TrackDB;

is(PomCur::DB::_make_short_classname('pub_status'), 'PubStatus');

is(PomCur::TrackDB->class_name_of_table('pub_status'),
   'PomCur::TrackDB::PubStatus');
is(PomCur::DB::table_name_of_class('PomCur::TrackDB::PubStatus'),
   'pub_status');
is(PomCur::DB::table_name_of_class('PubStatus'), 'pub_status');
