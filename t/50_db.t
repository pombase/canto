use strict;
use warnings;
use Test::More tests => 1;

use PomCur::DB;
use PomCur::TrackDB;

is(PomCur::TrackDB->class_name_of_table('pub_status'),
   'PomCur::TrackDB::PubStatus');
