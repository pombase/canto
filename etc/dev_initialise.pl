#!/usr/bin/perl -w

# create empty template database from the schemas and recreate the
# database classes

BEGIN {
  push @INC, "lib";
}

use strict;
use warnings;
use Carp;

use DBIx::Class::Schema::Loader qw(make_schema_at);

use PomCur::Config;
use PomCur::Track;

# Create empty databases
PomCur::Track::create_template_dbs();

my $config = PomCur::Config::get_config();

my %db_template_files = (
  Track => $config->{track_db_template_file},
  Curs => $config->{curs_db_template_file}
);

# change the methods on the objects so we can say $cvterm->cv()
# rather than $cvterm->cv_id() to get the CV
sub remove_id {
  my $relname = shift;
  my $res = Lingua::EN::Inflect::Number::to_S($relname);
  $res =~ s/_id$//;
  return $res;
}

sub make_schema
{
  my $schema_class = shift;
  my $connect_string = shift;

  die unless defined $schema_class and defined $connect_string;

  make_schema_at($schema_class,
                   { debug => 0, dump_directory => './lib', inflect_singular =>
                       \&remove_id },
                 [ $connect_string ]);
}

for my $schema_name (keys %db_template_files) {
  my $schema_class = "PomCur::${schema_name}DB";
  my $connect_string = "dbi:SQLite:dbname=$db_template_files{$schema_name}";

  make_schema($schema_class, $connect_string);
}
