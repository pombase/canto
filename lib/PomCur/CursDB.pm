package PomCur::CursDB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use Moose;
use namespace::autoclean;
extends 'PomCur::DB';

__PACKAGE__->load_classes;


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-15 15:26:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jYsxBRVsK1/YFWw7cNM6XA

__PACKAGE__->initialise();

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
