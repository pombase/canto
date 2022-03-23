#!/usr/bin/env perl

use strict;
use warnings;
use Carp;

use Getopt::Long;
use File::Basename;

BEGIN {
  $ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }

};

use lib qw(lib);

use Canto::TrackDB;
use Canto::Track::PubmedUtil;
use Canto::Config;


my $config = Canto::Config::get_config();
my $schema = Canto::TrackDB->new(config => $config);


my $do_fields = 0;
my $update_field_name = undef;
my $dry_run = 0;
my $do_help = 0;

my $result = GetOptions ("add-missing-fields|f" => \$do_fields,
                         "update-field=s" => \$update_field_name,
                         "dry-run|d" => \$dry_run,
                         "help|h" => \$do_help);

if (!$result || $do_help) {
  die "$0: needs one argument:
  --add-missing-fields (or -f): access PubMed to add missing title, abstract,
          authors, etc. to publications in the publications table (pub)
  --update-field <field_name>: re-initialise a single field in the pub table
          from the PubMed XML - the field is set to null then we call the code
          for --add-missing-field

";
}

my $guard = $schema->txn_scope_guard();

if ($do_fields) {
  my $count = Canto::Track::PubmedUtil::add_missing_fields($config, $schema);

  print "added missing fields to $count publications\n";
} else {
  if ($update_field_name) {
    my $count = Canto::Track::PubmedUtil::update_field($config, $schema, $update_field_name);

    print "updated $update_field_name in $count publications\n";
  }
}


$guard->commit() unless $dry_run;
