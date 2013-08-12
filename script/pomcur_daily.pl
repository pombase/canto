#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use feature ':5.10';

use File::Basename;
use POSIX qw/strftime/;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use PomCur::Config;
use PomCur::TrackDB;
use PomCur::MailSender;
use PomCur::EmailUtil;
use PomCur::Meta::Util;

my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}

my $send_mail = 1;

if (@ARGV >= 1 && $ARGV[0] eq '-s') {
  shift;
  # stdout instead
  $send_mail = 0;
}

if (@ARGV != 1 && @ARGV != 2) {
  die "$0: needs at least one argument:
$0 [-s] <canto_base_url> [summary_date]

where <canto_base_url> is the root URL for the application

flags:
  -s  send output to STDOUT instead of sending an email
";
}

my $canto_base_url = shift;
my $summary_date = shift;

if (!defined $summary_date) {
  my ($s, $min, $h, $d, $month, $y) = localtime();
  $summary_date = strftime "%Y-%m-%d", $s, $min, $h, $d - 1, $month, $y;
}

if ($canto_base_url !~ m|://|) {
  die qq("$canto_base_url" doesn't look like a URL\n);
}

my $config = PomCur::Config::get_config();
my $track_schema = PomCur::TrackDB->new(config => $config);

my $mail_sender = PomCur::MailSender->new(config => $config);
my $email_util = PomCur::EmailUtil->new(config => $config);

my %args = (track_schema => $track_schema,
            summary_date => $summary_date,
            app_prefix => $canto_base_url);

my ($subject, $body) = $email_util->make_email('daily_summary', %args);

if ($send_mail) {
  $mail_sender->send_to_admin(subject => $subject,
                              body => $body);
} else {
  print "Subject: $subject\n\ndetail: $body\n";
}

