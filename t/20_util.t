use strict;
use warnings;
use Test::More tests => 1;

use Canto::Util;

my $datetime = Canto::Util::get_current_datetime();
like ($datetime, qr(^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$));
