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

use Canto::Config;
use Canto::TrackDB;
use Canto::Track;
use Canto::Track::LoadUtil;
use Canto::Meta::Util;

my $remove_person = undef;
my $remove_lab = undef;
my $remove_curs = undef;
my $remove_all_sessions = undef;
my $remove_pub = undef;
my $do_help = 0;

if (!@ARGV) {
  usage();
}

my $result = GetOptions ("person=s" => \$remove_person,
                         "lab=s" => \$remove_lab,
                         "curs" => \$remove_curs,
                         "all-canto-sessions!" => \$remove_all_sessions,
                         "pub" => \$remove_pub,
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
OR
  $0 --curs <session_key> [<session_key> [<session_key>] ...]
OR
  $0 --pub <pubmed_id> [<pubmed_id> [<pubmed_id>]...]
OR
  $0 --all-canto-sessions

Options:
  --person - remove the person with the given email address, and unassign any
       publications and sessions assigned to this user
  --lab - remove the lab with the given name.
  --curs - remove a curation session (curs) and the curs database
  --pub - remove a publication from the database, unless it has a session
  --all-canto-sessions - remove ALL sessions

Example:
  $0 --pub PMID:9161420 PMID:8937892

|;
}

if ($do_help) {
  usage();
}

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();
my $schema = Canto::TrackDB->new(config => $config);

my $load_util = Canto::Track::LoadUtil->new(schema => $schema);

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
        my @curs_curators = $person->curs_curators();
        map {
          $_->delete();
        } @curs_curators;

        my @assigned_publications = $person->pubs();
        map {
          $_->corresponding_author(undef);
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
  if (defined $remove_curs) {
    for my $curs_key (@ARGV) {
      warn "removing: $curs_key\n";
      Canto::Track::delete_curs($config, $schema, $curs_key);
    }
    $exit_flag = 0;
  }
  if (defined $remove_pub) {
    for my $pub_uniquename (@ARGV) {
      if (Canto::Track::delete_pub($config, $schema, $pub_uniquename)) {
        print "successfully removed $pub_uniquename\n";
      }
    }
    $exit_flag = 0;
  }
  if (defined $remove_all_sessions) {
    my @keys = Canto::Track::all_curs_keys($schema);

    for my $curs_key (sort @keys) {
      warn "removing: $curs_key\n";
      Canto::Track::delete_curs($config, $schema, $curs_key);
    }
    $exit_flag = 0;
  }
};

$schema->txn_do($proc);

exit($exit_flag);
