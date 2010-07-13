package PomCur::TrackDB;

use strict;
use warnings;

use base 'DBIx::Class::Schema';

use base 'PomCur::DB';

__PACKAGE__->load_classes();
__PACKAGE__->initialise();

# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-07-13 18:09:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qx7uGDbWdXzbLjIYQ2x8Qw

for my $source (__PACKAGE__->sources()) {
  __PACKAGE__->source($source)->resultset_class('PomCur::DB::ResultSet');
}

# You can replace this text with custom content, and it will be preserved on regeneration
1;
