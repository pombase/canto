package PomCur::TrackDB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'PomCur::DB';

__PACKAGE__->load_classes;


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-12-16 10:43:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AFD45aiOjDjzuu9oC08Q4Q

__PACKAGE__->initialise();

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
