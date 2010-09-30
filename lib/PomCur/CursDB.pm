package PomCur::CursDB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'PomCur::DB';

__PACKAGE__->load_classes;


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-09-30 16:16:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ca0XJaFjA1pp1iyJQ6QN9Q

use base 'PomCur::DB';

__PACKAGE__->initialise();

# You can replace this text with custom content, and it will be preserved on regeneration
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
