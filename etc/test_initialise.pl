#!/usr/bin/perl -w

# script to set up the test database

use strict;
use warnings;
use Carp;

use Text::CSV;
use File::Copy qw(copy);

BEGIN {
  push @INC, "lib";
}

use PomCur::TrackDB;
use PomCur::Config;

my $config = PomCur::Config->new("pomcur.yaml", "t/test_config.yaml");

my $spreadsheet_file = $config->{test_config}->{curation_spreadsheet};
my $genes_file = $config->{test_config}->{test_genes_file};

my $track_test_db =
  $config->{test_config}->{track_test_db};

my $track_db_template_file = $config->{track_db_template_file};

unlink $track_test_db;

copy $track_db_template_file, $track_test_db;

%{$config->{"Model::TrackModel"}} = (
  schema_class => 'PomCur::TrackDB',
  connect_info => ["dbi:SQLite:dbname=$track_test_db"],
);

my $schema = PomCur::TrackDB->new($config);

my $curation_csv = Text::CSV->new({binary => 1});
open my $curation_io, '<', $spreadsheet_file or die;
$curation_csv->column_names ($curation_csv->getline($curation_io));

my $genes_csv = Text::CSV->new({binary => 1});
open my $genes_io, '<', $genes_file or die;
$genes_csv->column_names ($genes_csv->getline($genes_io));

my %people = ();
my %labs = ();
my %pubs = ();

my %pub_titles = (
  7958849  => "A heteromeric protein that binds to a meiotic homologous recombination hot spot: correlation of binding and hot spot activity.",
  19351719 => "A nucleolar protein allows viability in the absence of the essential ER-residing molecular chaperone calnexin.",
  17304215 => "Fission yeast Swi5/Sfr1 and Rhp55/Rhp57 differentially regulate Rhp51-dependent recombination outcomes.",
  19686603 => "Functional mapping of the fission yeast DNA polymerase delta B-subunit Cdc1 by site-directed and random pentapeptide insertion mutagenesis.",
  19160458 => "Improved tools for efficient mapping of fission yeast genes: identification of microtubule nucleation modifier mod22-1 as an allele of chromatin- remodelling factor gene swr1.",
  19664060 => "Inactivating pentapeptide insertions in the fission yeast replication factor C subunit Rfc2 cluster near the ATP-binding site and arginine finger motif.",
  19041767 => "Insig regulates HMG-CoA reductase by controlling enzyme phosphorylation in fission yeast.",
  19037101 => "Mus81, Rhp51(Rad51), and Rqh1 form an epistatic pathway required for the S-phase DNA damage checkpoint.",
  19436749 => "Phosphorylation-independent regulation of Atf1-promoted meiotic recombination by stress-activated, p38 kinase Spc1 of fission yeast.",
  7518718 => "RNA associated with a heterodimeric protein that activates a meiotic homologous recombination hot spot: RL/RT/PCR strategy for cloning any unknown RNA or DNA.",
  18430926 => "Schizosaccharomyces pombe Hsp90/Git10 is required for glucose/cAMP signaling.",
  19056896 => "The S. pombe SAGA complex controls the switch from proliferation to sexual differentiation through the opposing roles of its subunits Gcn5 and Spt8.",
  18426916 => "The anaphase-promoting complex/cyclosome controls repair and recombination by ubiquitylating Rhp54 in fission yeast.",
);

sub get_pub
{
  my $pubmed_id = shift;

  if (!exists $pubs{$pubmed_id}) {
    my $pub = $schema->create_with_type('Pub',
                                        {
                                          pubmedid => $pubmed_id,
                                          title => $pub_titles{$pubmed_id},
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

sub process_gene_row
{
  my $columns_ref = shift;
  my ($primary_name, $product, $name) = @{$columns_ref};

  $schema->create_with_type('Gene',
                            {
                              primary_identifier => $primary_name,
                              product => $product,
                              name => $name,
                            });
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

  while (my $columns_ref = $curation_csv->getline($curation_io)) {
    process_row($columns_ref, $user_cvterm);
  }

  while (my $columns_ref = $genes_csv->getline($genes_io)) {
    process_gene_row($columns_ref, $user_cvterm);
  }
}

eval {
  $schema->txn_do(\&process);
};
if ($@) {
  die "ROLLBACK called: $@\n";
}
