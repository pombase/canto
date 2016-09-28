#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use feature ':5.10';

use File::Basename;

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
use Canto::Meta::Util;

my $do_merge = 0;

if (@ARGV) {
  if ($ARGV[0] eq '-m') {
    $do_merge = 1;
    shift;
  }
}

my $dry_run = 0;

if (@ARGV) {
  if ($ARGV[0] eq '-d') {
    $dry_run = 1;
    shift;
  }
}

my $name = shift // die "needs a person name\n";
$name =~ s/\s*(.*?)\s*$/$1/;
my $email = shift // die "needs a person name and an email address\n";

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();
my $schema = Canto::TrackDB->new(config => $config);

my $email_match_person = $schema->resultset('Person')->find({ email_address => $email });

if (!$email_match_person) {
  die qq(can't find a Person with the email "$email"\n);
}

if ($email_match_person->name() !~ /^\s*$name\s*$/) {
  die 'name of Person in the database ("', $email_match_person->name(),
    qq|") doesn't match the argument name ("$name")\n|;
}

my $person_rs = $schema->resultset('Person')
  ->search({}, { where => \"name like '\%$name\%'" });

my @people_to_merge = ();

print qq(other Person entries with the name "$name":\n);
while (defined (my $person = $person_rs->next())) {
  next if $person->person_id() == $email_match_person->person_id();

  print $person->name(), ' - ', $person->email_address(), "\n";

  my $lab = $person->lab();

  if ($lab) {
    print "  in lab: ", $lab->name(), ' (', $lab->lab_head()->name(), ")\n";
  }

  my @labs = $person->labs();

  for my $lab (@labs) {
    print "  head of lab: ", $lab->name(), "\n";
  }

  push @people_to_merge, $person;
}

exit 0 unless $do_merge;

my $guard = $schema->txn_scope_guard();

print "\nMerging ...\n" if @people_to_merge > 0;

my %email_map = ();

for my $person (@people_to_merge) {
  print "  ", $person->email_address(), "\n";
  print "    ", scalar($person->pubs()), " pubs\n";
  for my $pub ($person->pubs()) {
    $pub->corresponding_author($email_match_person);
    $pub->update();
  }

  print "    ", scalar($person->curs_curators()), " session curators\n";
  for my $curs_curator ($person->curs_curators()) {
    $curs_curator->curator($email_match_person);
    $curs_curator->update();
  }

  if ($person->lab()) {
    print "    lab (", $person->lab()->name(), ")\n";
    $email_match_person->lab($person->lab());
    $email_match_person->update();
  }

  for my $lab ($person->labs()) {
    print "    head of lab: ", $lab->name(), "\n";
    $lab->lab_head($email_match_person);
    $lab->update();
  }

  $email_map{$person->email_address()} = $email_match_person->email_address();

  $person->delete();
}

if (!$dry_run) {
  my $trackdb = Canto::TrackDB->new(config => $config);
  my $iter = Canto::Track::curs_iterator($config, $trackdb);

  while (my ($curs, $cursdb) = $iter->()) {
    my $rs = $cursdb->resultset("Annotation");
    while (defined (my $a = $rs->next())) {
      my $data = $a->data();
      my $current_email = $data->{curator}->{email};

      if ($current_email && exists $email_map{$current_email}) {
        $data->{curator}->{email} = $email_map{$current_email};

        print " ", $curs->curs_key(), ": updating $current_email to ",
          $email_map{$current_email}, "\n";

        $a->data($data);
        $a->update();
      }
    }

    $cursdb->disconnect();
  }
}

$guard->commit() unless $dry_run;
