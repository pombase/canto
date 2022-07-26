#!/usr/bin/env perl

use strict;
use warnings;
use Carp;


# load an PubMed XML file into the database - mostly for testing

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


$/ = undef;

my $xml_content = <>;


my $guard = $schema->txn_scope_guard();

Canto::Track::PubmedUtil::load_pubmed_xml($schema, $xml_content, 'admin_load');

$guard->commit() unless 1;
