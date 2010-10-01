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


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-09-30 16:18:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Qe5Bl/pWROrH+BZjMVLEbg

__PACKAGE__->initialise();

__PACKAGE__->meta->make_immutable;

1;
