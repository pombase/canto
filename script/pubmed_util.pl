#!/usr/bin/perl -w

use strict;
use warnings;
use Carp;

use Getopt::Long;

BEGIN {
  $ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';
  push @INC, qw(lib ../lib);
}

use PomCur::TrackDB;
use PomCur::Track::PubmedUtil;
use PomCur::Config;


my $config = PomCur::Config::get_config();
my $schema = PomCur::TrackDB->new($config);


my $do_title = 0;
my $do_help = 0;

my $result = GetOptions ("title|t" => \$do_title,
                         "help|h" => \$do_help);

if (!$result || $do_help) {
  die "$0: needs one argument:
  --add-missing-titles (or -t): access pubmed to add missing title to
          publications in the pub table
\n";
}

my $count = PomCur::Track::PubmedUtil::add_missing_titles($config, $schema);

print "added $count titles\n";
