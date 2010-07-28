#!/usr/bin/perl -w

use strict;
use warnings;
use Carp;

use Text::CSV;

use PomCur::TrackDB;
use PomCur::Config;

my $spreadsheet_file = shift;

my $config = PomCur::Config->new("pomcur.yaml", "t/pomcur_loading_config.yaml",
                                 "t/test_config.yaml");
my $schema = PomCur::TrackDB->new($config);

my $csv = Text::CSV->new({binary => 1});

open my $io, '<', $spreadsheet_file or die;

$csv->column_names ($csv->getline($io));

my %people = ();
my %labs = ();
my %pubs = ();

sub get_pub
{
  my $pubmed_id = shift;

  if (!exists $pubs{$pubmed_id}) {
    my $pub = $schema->create_with_type('Pub',
                                        {
                                          pubmedid => $pubmed_id
                                         });

    $pubs{$pubmed_id} = $pub;
  }

  return $pubs{$pubmed_id};
}

sub get_lab
{
  my $lab_head = shift;

  my $lab_head_name = $lab_head->longname();

  (my $lab_head_surname = $lab_head_name) =~ s/.* //;

  if (!exists $labs{$lab_head_name}) {
    my $lab = $schema->create_with_type('Lab',
                                        {
                                          lab_head => $lab_head,
                                          name => "$lab_head_surname Lab"
                                         });

    $labs{$lab_head_name} = $lab;
  }

  return $labs{$lab_head_name};
}

sub get_person
{
  my $longname = shift;
  my $networkaddress = shift;
  my $role_cvterm = shift;

  if (!defined $networkaddress || length $networkaddress == 0) {
    die "email not set for $longname\n";
  }
  if (!defined $longname || length $longname == 0) {
    die "name not set for $networkaddress\n";
  }

  if (!exists $people{$longname}) {
    my $person = $schema->create_with_type('Person',
                                           {
                                             longname => $longname,
                                             networkaddress => $networkaddress,
                                             password => $networkaddress,
                                             role => $role_cvterm,
                                           });

    $people{$longname} = $person;
  }

  return $people{$longname};
}

sub fix_lab
{
  my ($person, $lab) = @_;

  if (!defined $person->lab()) {
    $person->lab($lab);
    $person->update();
  }
}

sub process_row
{
  my $columns_ref = shift;
  my $user_cvterm = shift;

  my ($pubmed_id, $lab_head_name, $submitter_name, $date_sent, $status,
      $lab_head_email, $submitter_email) = @{$columns_ref};

  my $pub = get_pub($pubmed_id);
  my $lab_head = get_person($lab_head_name, $lab_head_email, $user_cvterm);
  my $lab = get_lab($lab_head);
  my $submitter = undef;

  if ($submitter || $submitter_email) {
    $submitter = get_person($submitter_name, $submitter_email, $user_cvterm);
  }

  if (!defined ($submitter)) {
    $submitter = $lab_head;
  }

  fix_lab($lab_head, $lab);
  fix_lab($submitter, $lab);
}

sub process
{
  my $cv = $schema->create_with_type('Cv', { name => 'pomcur user types' });
  my $user_cvterm = $schema->create_with_type('Cvterm', { cv => $cv,
                                                          name => 'user',
                                                        });
  my $admin_cvterm = $schema->create_with_type('Cvterm', { cv => $cv,
                                                           name => 'admin',
                                                         });

  my $admin = get_person('Val Wood', 'val@sanger.ac.uk', $admin_cvterm);

  while (my $columns_ref = $csv->getline($io)) {
    process_row($columns_ref, $user_cvterm);
  }
}

eval {
  $schema->txn_do(\&process);
};
if ($@) {
  die "ROLLBACK called: $@\n";
}
