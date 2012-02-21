#!/usr/bin/perl -w

use strict;
use warnings;
use Carp;
use feature ':5.10';

use File::Basename;
use Getopt::Long;

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
use PomCur::Track::LoadUtil;
use PomCur::Meta::Util;

my $remove_person = undef;
my $remove_lab = undef;
my $dry_run = 0;
my $do_help = 0;

if (!@ARGV) {
  usage();
}

my $result = GetOptions ("person=s" => \$remove_person,
                         "lab=s" => \$remove_lab,
                         "dry-run|T" => \$dry_run,
                         "help|h" => \$do_help);

sub usage
{
  my $message = shift;

  if (defined $message) {
    $message .= "\n";
  } else {
    $message = '';
  }

  die qq|${message}usage:
  $0 --person <email_address>
OR
  $0 --lab <lab_name>

Options:
  --person - remove the person with the given email address, and unassign any
       publications and sessions assigned to this user
  --lab - remove the lab with the given name.
|;
}

if ($do_help) {
  usage();
}

my $app_name = PomCur::Config::get_application_name();

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{POMCUR_CONFIG_LOCAL_SUFFIX};

if (!PomCur::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the pomcur_start " .
    "script\n";
}

my $config = PomCur::Config::get_config();
my $schema = PomCur::TrackDB->new(config => $config);

my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);

my $exit_flag = 1;

my $proc = sub {
  if (defined $remove_person) {
    my $person = $schema->resultset('Person')->find({ email_address => $remove_person });

    if (defined $person) {
      my @labs = $person->labs();
      if (@labs) {
        my $lab_string = join ', ', map { $_->name() } @labs;
        my $person_name = $person->name();
        warn "Can't delete $person_name who is lab head of: $lab_string
Delete the lab first with:
  $0 --lab '", $labs[0]->name(), "'\n";
      } else {
        my @assigned_curation_sessions = $person->curs();
        map {
          $_->assigned_curator(undef);
          $_->update();
        } @assigned_curation_sessions;

        my @assigned_publications = $person->pubs();
        map {
          $_->assigned_curator(undef);
          $_->update();
        } @assigned_publications;

        $person->delete();
        $exit_flag = 0;
      }
    } else {
      warn "No person found for email address: $remove_person\n";
    }
  }
  if (defined $remove_lab) {
    my $lab = $schema->resultset('Lab')->find({ name => $remove_lab });

    if (defined $lab) {
      map { $_->lab(undef); $_->update(); } $lab->people();
      $lab->delete();
      $exit_flag = 0;
    } else {
      warn "No lab found named: $remove_lab\n";
    }
  }
};

$schema->txn_do($proc);

exit($exit_flag);
