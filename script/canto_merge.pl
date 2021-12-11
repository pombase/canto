#!/usr/bin/env perl

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
use Canto::Meta::Util;

my $merge_person = 0;
my $do_help = 0;

if (!@ARGV) {
  usage();
}

my $result = GetOptions ("person" => \$merge_person,
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
  $0 --person <email_address_to_remove> <destination_email_address>

Options:
  --person - merge person with email "email_address_to_remove" into person
             with email "destination_email_address"
             Curation sessions will be moved to the destination person

Example:
  $0 --person some.user\@old-domain.example.com s.user\@new-machine.example.com

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


if ($merge_person) {
  if (@ARGV != 2) {
    usage "--person needs two arguments";
  }
}

if (defined $merge_person) {
  my ($person_to_remove_email, $dest_person_email) = @ARGV;

  if ($person_to_remove_email eq $dest_person_email) {
    usage "duplicate email: $person_to_remove_email";
  }

  my $person_to_remove =
    $schema->resultset('Person')->find({ email_address => $person_to_remove_email });
  my $dest_person =
    $schema->resultset('Person')->find({ email_address => $dest_person_email });

  if (!defined $person_to_remove) {
    die "can't find person in the database: $person_to_remove_email\n";
  }

  if (!defined $dest_person) {
    die "can't find person in the database: $dest_person_email\n";
  }

  my $person_to_remove_name = $person_to_remove->name();
  my $dest_person_name = $dest_person->name();

  if ($person_to_remove->orcid() && !$dest_person->orcid()) {
    $dest_person->orcid($person_to_remove->orcid());
    $dest_person->update();
  }
  if ($person_to_remove->known_as() && !$dest_person->known_as()) {
    $dest_person->known_as($person_to_remove->known_as());
    $dest_person->update();
  }

  my @labs = $person_to_remove->labs();

  if (@labs) {

    my $lab_string = join ', ', map { $_->name() } @labs;
    die "Can't delete $person_to_remove_email who is lab head of: $lab_string
Delete the lab first with:
  canto_delete.pl --lab '", $labs[0]->name(), "'\n";

  } else {

    my @curs_curators = $person_to_remove->curs_curators();
    map {
      $_->curator($dest_person);
      $_->update();
    } @curs_curators;

    my @assigned_publications = $person_to_remove->pubs();
    map {
      $_->corresponding_author($dest_person);
      $_->update();
    } @assigned_publications;

    $person_to_remove->delete();

    my $update_proc = sub {

      my $curs = shift;
      my $curs_key = $curs->curs_key();
      my $curs_schema = shift;

      my $annotation_rs = $curs_schema->resultset('Annotation');

      for my $an ($annotation_rs->all()) {
        my $data = $an->data();

        my $curator = $data->{curator};

        if ($curator->{email} eq $person_to_remove_email) {
          $curator->{email} = $dest_person_email;
          $curator->{name} = $dest_person->name();
          $data->{curator} = $curator;
          $an->data($data);
          $an->update();
        }
      }

      my $metadata_rs = $curs_schema->resultset('Metadata');

      my $updated_first_contact = 0;
      for my $md ($metadata_rs->all()) {
        if ($md->key() eq 'first_contact_email' && $md->value() eq $person_to_remove_email) {
          $md->value($dest_person_email);
          $md->update();
          $updated_first_contact = 1;
        }
      }

      for my $md ($metadata_rs->all()) {
        if ($md->key() eq 'first_contact_name' && $updated_first_contact) {
          $md->value($dest_person->name());
          $md->update();
        }
      }
    };

    warn "user merged, checking sessions ...\n";

    Canto::Track::curs_map($config, $schema, $update_proc);

  }
}

exit(0);
