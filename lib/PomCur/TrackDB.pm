use utf8;
package PomCur::TrackDB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use Moose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'PomCur::DB';

__PACKAGE__->load_classes;


# Created by DBIx::Class::Schema::Loader v0.07017 @ 2012-03-26 04:28:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZR3wAaNzYOMx45rn9p7ngg

__PACKAGE__->initialise();

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
