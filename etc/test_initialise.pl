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

use PomCur::Track;
use PomCur::TrackDB;
use PomCur::Config;
use PomCur::TestUtil;

my %test_curators = ();
my %test_publications = ();
my %test_schemas = ();

my $test_util = PomCur::TestUtil->new();

my $config = PomCur::Config->new("pomcur.yaml", "t/test_config.yaml");

$config->{data_directory} = $test_util->root_dir() . '/t/data';

my $spreadsheet_file = $config->{test_config}->{curation_spreadsheet};
my $genes_file = $config->{test_config}->{test_genes_file};

my $base_track_db_file_name;
($test_schemas{"0_curs"}, $base_track_db_file_name) =
  PomCur::TestUtil::make_track_test_db($config, 'track_test_0_curs_db');

my $curation_csv = Text::CSV->new({binary => 1});
open my $curation_io, '<', $spreadsheet_file or die;
$curation_csv->column_names ($curation_csv->getline($curation_io));

my $genes_csv = Text::CSV->new({binary => 1});
open my $genes_io, '<', $genes_file or die;
$genes_csv->column_names ($genes_csv->getline($genes_io));

my %test_cases = %{$config->{test_config}->{test_cases}};

my %people = ();
my %labs = ();
my %pubs = ();
my %organisms = ();
my %cvs = ();
my %cvterms = ();

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

sub get_organism
{
  my $schema = shift;
  my $genus = shift;
  my $species = shift;

  my $full_name = "$genus $species";

  if (!exists $organisms{$full_name}) {
    my $organism = $schema->create_with_type('Organism',
                                             {
                                               genus => $genus,
                                               species => $species,
                                             });

    $organisms{$full_name} = $organism;
  }

  return $organisms{$full_name};
}

sub get_cv
{
  my $schema = shift;
  my $cv_name = shift;

  if (!exists $cvs{$cv_name}) {
    my $cv = $schema->create_with_type('Cv',
                                       {
                                         name => $cv_name
                                       });

    $cvs{$cv_name} = $cv;
  }

  return $cvs{$cv_name};
}

sub get_cvterm
{
  my $schema = shift;
  my $cv = shift;
  my $cvterm_name = shift;

  if (!exists $cvterms{$cvterm_name}) {
    my $cvterm = $schema->create_with_type('Cvterm',
                                           {
                                             name => $cvterm_name,
                                             cv => $cv,
                                           });

    $cvterms{$cvterm_name} = $cvterm;
  }

  return $cvterms{$cvterm_name};
}

sub get_pub
{
  my $schema = shift;
  my $pubmed_id = shift;

  my $pub_type_cv = get_cv($schema, 'PomBase publication type');
  my $pub_type = get_cvterm($schema, $pub_type_cv, 'unknown');

  if (!exists $pubs{$pubmed_id}) {
    my $pub = $schema->create_with_type('Pub',
                                        {
                                          pubmedid => $pubmed_id,
                                          title => $pub_titles{$pubmed_id},
                                          type => $pub_type,
                                        });

    $pubs{$pubmed_id} = $pub;
  }

  return $pubs{$pubmed_id};
}

sub get_lab
{
  my $schema = shift;
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
  my $schema = shift;
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
  my $schema = shift;
  my $columns_ref = shift;
  my $user_cvterm = shift;

  my ($pubmed_id, $lab_head_name, $submitter_name, $date_sent, $status,
      $lab_head_email, $submitter_email) = @{$columns_ref};

  my $pub = get_pub($schema, $pubmed_id);
  my $lab_head = get_person($schema, $lab_head_name, $lab_head_email, $user_cvterm);
  my $lab = get_lab($schema, $lab_head);
  my $submitter = undef;

  if ($submitter_email) {
    $submitter = get_person($schema, $submitter_name, $submitter_email, $user_cvterm);
  }

  if (!defined ($submitter)) {
    $submitter = $lab_head;
  }

  $test_curators{$lab_head_email} = $lab_head;
  $test_publications{$pubmed_id} = $pub;

  fix_lab($lab_head, $lab);
  fix_lab($submitter, $lab);
}

sub process_gene_row
{
  my $schema = shift;
  my $columns_ref = shift;
  my ($primary_name, $product, $name) = @{$columns_ref};

  my $pombe = get_organism($schema, 'Schizosaccharomyces', 'pombe');

  $schema->create_with_type('Gene',
                            {
                              primary_identifier => $primary_name,
                              product => $product,
                              primary_name => $name,
                              organism => $pombe
                            });
}

# populate base track database ("0_curs"), with no curation sessions (curs
# objects)
eval {
  my $schema = $test_schemas{"0_curs"};

  my $process =
    sub {
      my $cv = get_cv($schema, 'PomBase user types');
      my $user_cvterm = get_cvterm($schema, $cv, 'user');
      my $admin_cvterm = get_cvterm($schema, $cv, 'admin');

      my $admin = get_person($schema, 'Val Wood', 'val@sanger.ac.uk',
                             $admin_cvterm);

      while (my $columns_ref = $curation_csv->getline($curation_io)) {
        process_row($schema, $columns_ref, $user_cvterm);
      }

      while (my $columns_ref = $genes_csv->getline($genes_io)) {
        process_gene_row($schema, $columns_ref, $user_cvterm);
      }
    };

  $schema->txn_do($process);
};
if ($@) {
  die "ROLLBACK called: $@\n";
}

sub make_curs_dbs
{
  my $test_case_key = shift;

  my $test_case = $test_cases{$test_case_key};
  my $schema = $test_schemas{$test_case_key};

  my $pombe = get_organism($schema, 'Schizosaccharomyces', 'pombe');

  my $process_test_case =
    sub {
      for my $test_case_ref (@$test_case) {
        my $test_case_curs_key =
          PomCur::TestUtil::curs_key_of_test_case($test_case_ref);

        my $create_args = {
          community_curator => $test_curators{$test_case_ref->{first_contact}},
          curs_key => $test_case_curs_key,
          pub => $test_publications{$test_case_ref->{pubmedid}},
        };

        my $curs_object = $schema->create_with_type('Curs', $create_args);

        my $curs_file_name =
          PomCur::Curs::make_long_db_file_name($config, $test_case_curs_key);
        unlink $curs_file_name;

        PomCur::Track::create_curs_db($config, $curs_object);
      }
    };

  eval {
    $test_schemas{$test_case_key}->txn_do($process_test_case);
  };
  if ($@) {
    die "ROLLBACK called: $@\n";
  }
}

# copy base track database to other test case track dbs, and create some curs
# objects
my $track_1_curs_db_file_name;

($test_schemas{'1_curs'}, $track_1_curs_db_file_name) =
  PomCur::TestUtil::make_track_test_db($config, 'track_test_1_curs_db',
                                       $base_track_db_file_name);


make_curs_dbs('1_curs');

my $track_3_curs_db_file_name;

($test_schemas{'3_curs'}, $track_3_curs_db_file_name) =
  PomCur::TestUtil::make_track_test_db($config, 'track_test_3_curs_db',
                                       $track_1_curs_db_file_name);


make_curs_dbs('3_curs');

warn "Test initialisation complete\n";
