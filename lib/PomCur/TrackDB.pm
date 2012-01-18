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


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-01-18 02:49:31
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZvjlWyCK2Z9dDhEYvNFs0w

__PACKAGE__->initialise();

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
