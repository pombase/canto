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
use PomCur::Meta::Util;

# Create empty databases
PomCur::Meta::Util::create_template_dbs();

my $config = PomCur::Config::get_config();

my %db_template_files = (
  Track => $config->{track_db_template_file},
  Curs => $config->{curs_db_template_file}
);

# change the methods on the objects so we can say $cvterm->cv()
# rather than $cvterm->cv_id() to get the CV
sub remove_id {
  my $relname = shift;

  my $res;
  if ($relname eq 'curs') {
    $res = $relname;
  } else {
    $res = Lingua::EN::Inflect::Number::to_S($relname);
  }
  $res =~ s/_id$//;

  return $res;
}

sub make_schema
{
  my $schema_class = shift;
  my $connect_string = shift;

  die unless defined $schema_class and defined $connect_string;

  make_schema_at($schema_class,
                   {
                     debug => 0, dump_directory => './lib',
                     inflect_singular => \&remove_id,
                     naming => 'current',
                     schema_base_class => 'PomCur::DB',
                     use_moose => 1, use_namespaces => 0,
                     moniker_map => { curs => 'Curs',
                                      sessions => 'Sessions' },
                   },
                 [ $connect_string ]);
}

for my $schema_name (keys %db_template_files) {
  my $schema_class = "PomCur::${schema_name}DB";
  my $file_name = $db_template_files{$schema_name};
  my $connect_string = "dbi:SQLite:dbname=$file_name";

  make_schema($schema_class, $connect_string);

  my $schema =
    PomCur::DBUtil::schema_for_file($config, $file_name, $schema_name);

  PomCur::Meta::Util::initialise_core_data($config, $schema, lc $schema_name);
}

warn "finished initialising development environment\n";
