use strict;
use warnings;
use Test::More tests => 4;

use Canto::DB;
use Canto::TrackDB;

is(Canto::DB::_make_short_classname('pub_status'), 'PubStatus');

is(Canto::TrackDB->class_name_of_table('pub_status'),
   'Canto::TrackDB::PubStatus');
is(Canto::DB::table_name_of_class('Canto::TrackDB::PubStatus'),
   'pub_status');
is(Canto::DB::table_name_of_class('PubStatus'), 'pub_status');
