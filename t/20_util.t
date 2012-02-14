use strict;
use warnings;
use Test::More tests => 1;

use PomCur::Util;

my $datetime = PomCur::Util::get_current_datetime();
like ($datetime, qr(^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$));
