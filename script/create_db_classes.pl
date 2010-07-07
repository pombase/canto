#!/usr/bin/perl -w

# recreate the DB classes by reading the database schema

BEGIN {
  push @INC, "lib";
}

use strict;

use PomCur::Config;

my $schema_class = shift;
my $connect_string = shift;

die unless defined $schema_class and defined $connect_string;

use DBIx::Class::Schema::Loader qw(make_schema_at);

# change the methods on the objects so we can say $cvterm->cv()
# rather than $cvterm->cv_id() to get the CV
sub remove_id {
  my $relname = shift;
  my $res = Lingua::EN::Inflect::Number::to_S($relname);
  $res =~ s/_id$//;
  return $res;
}

make_schema_at($schema_class,
               { debug => 0, dump_directory => './lib', inflect_singular =>
                   \&remove_id },
               [ $connect_string ]);
