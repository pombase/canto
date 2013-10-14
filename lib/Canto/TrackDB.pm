use utf8;
package Canto::TrackDB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use Moose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'Canto::DB';

__PACKAGE__->load_classes;


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:27:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4B3/YQFbCZGovBPN/n+Bvg

__PACKAGE__->initialise();

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
