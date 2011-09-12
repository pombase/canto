#!/usr/bin/env perl

use strict;
use warnings;
use Carp;

use Getopt::Long;
use File::Basename;

BEGIN {
  $ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};
push @INC, "lib";

use PomCur::TrackDB;
use PomCur::Track::PubmedUtil;
use PomCur::Config;


my $config = PomCur::Config::get_config();
my $schema = PomCur::TrackDB->new(config => $config);


my $do_fields = 0;
my $do_help = 0;

my $result = GetOptions ("add-missing-fields|f" => \$do_fields,
                         "help|h" => \$do_help);

if (!$result || $do_help) {
  die "$0: needs one argument:
  --add-missing-fields (or -f): access pubmed to add missing title, abstract,
          authors, etc. to publications in the publications table (pub)
\n";
}

if ($do_fields) {
  my $count = PomCur::Track::PubmedUtil::add_missing_fields($config, $schema);

  print "added missing fields to $count publications\n";
}
