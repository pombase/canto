use utf8;
package Canto::CursDB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use Moose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'Canto::DB';

__PACKAGE__->load_classes;


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:24:35
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qe5uNM4PKNTz1GhbBaxVCA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
