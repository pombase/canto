#!/usr/bin/perl -w

# Create Perl classes for a Chado database

BEGIN {
  push @INC, "lib";
}

use strict;
use warnings;
use Carp;

use DBIx::Class::Schema::Loader qw(make_schema_at);

use PomCur::Config;

if (@ARGV != 3) {
  die "$0: error: a DBI connect string, username and password must be passed "
    . "on the command line\n";
}

my $config = PomCur::Config::get_config();

# change the methods on the objects so we can say $cvterm->cv()
# rather than $cvterm->cv_id() to get the CV
sub remove_id {
  my $relname = shift;
  my $res = Lingua::EN::Inflect::Number::to_S($relname);
  $res =~ s/_id$//;
  return $res;
}

my $schema_class = 'PomCur::ChadoDB';



my $connect_string = shift;
my $user = shift;
my $password = shift;

make_schema_at($schema_class,
                   {
                     debug => 0, dump_directory => './lib',
                     inflect_singular => \&remove_id,
                     naming => 'current',
                     schema_base_class => 'PomCur::DB',
                     use_moose => 1, use_namespaces => 0,
                   },
                 [ $connect_string, $user, $password ]);
