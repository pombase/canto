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
use PomCur::Track::CurationLoad;
use PomCur::Track::GeneLoad;
use PomCur::Track::LoadUtil;

my %test_curators = ();
my %test_publications = ();
my %test_schemas = ();

my $test_util = PomCur::TestUtil->new();

my $config = PomCur::Config->new("pomcur.yaml", "t/test_config.yaml");

$config->{data_directory} = $test_util->root_dir() . '/t/data';

my $curation_file = $config->{test_config}->{curation_spreadsheet};
my $genes_file = $config->{test_config}->{test_genes_file};

my $base_track_db_file_name;
($test_schemas{"0_curs"}, $base_track_db_file_name) =
  PomCur::TestUtil::make_track_test_db($config, 'track_test_0_curs_db');

my %test_cases = %{$config->{test_config}->{test_cases}};

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

my %pub_abstracts = (
  19351719 => "In fission yeast, the ER-residing molecular chaperone calnexin is normally essential for viability. However, a specific mutant of calnexin that is devoid of chaperone function (Deltahcd_Cnx1p) induces an epigenetic state that allows growth of Schizosaccharomyces pombe without calnexin. This calnexin-independent (Cin) state was previously shown to be mediated via a non-chromosomal element exhibiting some prion-like features. Here, we report the identification of a gene whose overexpression induces the appearance of stable Cin cells. This gene, here named cif1(+) for calnexin-independence factor 1, encodes an uncharacterized nucleolar protein. The Cin cells arising from cif1(+) overexpression (Cin(cif1) cells) are genetically and phenotypically distinct from the previously characterized Cin(Deltahcd_cnx1) cells, which spontaneously appear in the presence of the Deltahcd_Cnx1p mutant. Moreover, cif1(+) is not required for the induction or maintenance of the Cin(Deltahcd_cnx1) state. These observations argue for different pathways of induction and/or maintenance of the state of calnexin independence. Nucleolar localization of Cif1p is required to induce the Cin(cif1) state, thus suggesting an unexpected interaction between the vital cellular role of calnexin and a function of the nucleolus.",
  17304215 => "Several accessory proteins referred to as mediators are required for the full activity of the Rad51 (Rhp51 in fission yeast) recombinase. In this study, we analyzed in vivo functions of the recently discovered Swi5/Sfr1 complex from fission yeast. In normally growing cells, the Swi5-GFP protein localizes to the nucleus, where it forms a diffuse nuclear staining pattern with a few distinct foci. These spontaneous foci do not form in swi2Delta mutants. Upon UV irradiation, Swi5 focus formation is induced in swi2Delta mutants, a response that depends on Sfr1 function, and Sfr1 also forms foci that colocalize with damage-induced Rhp51 foci. The number of UV-induced Rhp51 foci is partially reduced in swi5Delta and rhp57Delta mutants and completely abolished in an swi5Delta rhp57Delta double mutant. An assay for products generated by HO endonuclease-induced DNA double-strand breaks (DSBs) reveals that Rhp51 and Rhp57, but not Swi5/Sfr1, are essential for crossover production. These results suggest that Swi5/Sfr1 functions as an Rhp51 mediator but processes DSBs in a manner different from that of the Rhp55/57 mediator.",
  19686603 => "BACKGROUND: DNA polymerase delta plays an essential role in chromosomal DNA replication in eukaryotic cells, being responsible for synthesising the bulk of the lagging strand. In fission yeast, Pol delta is a heterotetrameric enzyme comprising four evolutionarily well-conserved proteins: the catalytic subunit Pol3 and three smaller subunits Cdc1, Cdc27 and Cdm1. Pol3 binds directly to the B-subunit, Cdc1, which in turn binds the C-subunit, Cdc27. Human Pol delta comprises the same four subunits, and the crystal structure was recently reported of a complex of human p50 and the N-terminal domain of p66, the human orthologues of Cdc1 and Cdc27, respectively. RESULTS: To gain insights into the structure and function of Cdc1, random and directed mutagenesis techniques were used to create a collection of thirty alleles encoding mutant Cdc1 proteins. Each allele was tested for function in fission yeast and for binding of the altered protein to Pol3 and Cdc27 using the two-hybrid system. Additionally, the locations of the amino acid changes in each protein were mapped onto the three-dimensional structure of human p50. The results obtained from these studies identify amino acid residues and regions within the Cdc1 protein that are essential for interaction with Pol3 and Cdc27 and for in vivo function. Mutations specifically defective in Pol3-Cdc1 interactions allow the identification of a possible Pol3 binding surface on Cdc1. CONCLUSION: In the absence of a three-dimensional structure of the entire Pol delta complex, the results of this study highlight regions in Cdc1 that are vital for protein function in vivo and provide valuable clues to possible protein-protein interaction surfaces on the Cdc1 protein that will be important targets for further study.",
  19160458 => "Fission yeast genes identified in genetic screens are usually cloned by transformation of mutants with plasmid libraries. However, for some genes this can be difficult, and positional cloning approaches are required. The mutation swi5-39 reduces recombination frequency in homozygous crosses and has been used as a tool in mapping gene position (Schmidt, 1993). However, strain construction in swi5-39-based mapping is significantly more laborious than is desirable. Here we describe a set of strains designed to make swi5-based mapping more efficient and more powerful. The first improvement is the use of a swi5Delta strain marked with kanamycin (G418) resistance, which greatly facilitates identification of swi5 mutants. The second improvement, which follows directly from the first, is the introduction of a large number of auxotrophic markers into mapping strains, increasing the likelihood of finding close linkage between a marker and the mutation of interest. We combine these new mapping strains with a rec12Delta-based approach for initial mapping of a mutation to an individual chromosome. Together, the two methods allow an approximate determination of map position in only a small number of crosses. We used these to determine that mod22-1, a modifier of microtubule nucleation phenotypes, encodes a truncation allele of Swr1, a chromatin-remodelling factor involved in nucleosomal deposition of H2A.Z histone variant Pht1. Expression microarray analysis of mod22-1, swr1Delta and pht1Delta cells suggests that the modifier phenotype of mod22-1 mutants may be due to small changes in expression of one or more genes involved in tubulin function.",
  19664060 => "Replication factor C (RFC) plays a key role in eukaryotic chromosome replication by acting as a loading factor for the essential sliding clamp and polymerase processivity factor, proliferating cell nuclear antigen (PCNA). RFC is a pentamer comprising a large subunit, Rfc1, and four small subunits, Rfc2-Rfc5. Each RFC subunit is a member of the AAA+ family of ATPase and ATPase-like proteins, and the loading of PCNA onto double-stranded DNA is an ATP-dependent process. Here, we describe the properties of a collection of 38 mutant forms of the Rfc2 protein generated by pentapeptide-scanning mutagenesis of the fission yeast rfc2 gene. Each insertion was tested for its ability to support growth in fission yeast rfc2Delta cells lacking endogenous Rfc2 protein and the location of each insertion was mapped onto the 3D structure of budding yeast Rfc2. This analysis revealed that the majority of the inactivating mutations mapped in or adjacent to ATP sites C and D in Rfc2 (arginine finger and P-loop, respectively) or to the five-stranded beta sheet at the heart of the Rfc2 protein. By contrast, nonlethal mutations map predominantly to loop regions or to the outer surface of the RFC complex, often in highly conserved regions of the protein. Possible explanations for the effects of the various insertions are discussed.",
  19041767 => "Insig functions as a central regulator of cellular cholesterol homeostasis by controlling activity of HMG-CoA reductase (HMGR) in cholesterol synthesis. Insig both accelerates the degradation of HMGR and suppresses HMGR transcription through the SREBP-Scap pathway. The fission yeast Schizosaccharomyces pombe encodes homologs of Insig, HMGR, SREBP, and Scap, called ins1(+), hmg1(+), sre1(+), and scp1(+). Here, we characterize fission yeast Insig and demonstrate that Ins1 is dedicated to regulation of Hmg1, but not the Sre1-Scp1 pathway. Using a sterol-sensing domain mutant of Hmg1, we demonstrate that Ins1 binding to Hmg1 inhibits enzyme activity by promoting phosphorylation of the Hmg1 active site, which increases the K(M) for NADPH. Ins1-dependent phosphorylation of Hmg1 requires the MAP kinase Sty1/Spc1, and Hmg1 phosphorylation is physiologically regulated by nutrient stress. Thus, in fission yeast, Insig regulates sterol synthesis by a different mechanism than in mammalian cells, controlling HMGR phosphorylation in response to nutrient supply.",
  19037101 => "The S-phase DNA damage checkpoint slows the rate of DNA synthesis in response to damage during replication. In the fission yeast Schizosaccharomyces pombe, Cds1, the S-phase-specific checkpoint effector kinase, is required for checkpoint signaling and replication slowing; upon treatment with the alkylating agent methyl methane sulfonate, cds1Delta mutants display a complete checkpoint defect. We have identified proteins downstream of Cds1 required for checkpoint-dependant slowing, including the structure-specific endonuclease Mus81 and the helicase Rqh1, which are implicated in replication fork stability and the negative regulation of recombination. Removing Rhp51, the Rad51 recombinase homologue, suppresses the slowing defect of rqh1Delta mutants, but not that of mus81Delta mutant, defining an epistatic pathway in which mus81 is epistatic to rhp51 and rhp51 is epistatic to rqh1. We propose that restraining recombination is required for the slowing of replication in response to DNA damage.",
  19436749 => "BACKGROUND: Stress-activated protein kinases regulate multiple cellular responses to a wide variety of intracellular and extracellular conditions. The conserved, multifunctional, ATF/CREB protein Atf1 (Mts1, Gad7) of fission yeast binds to CRE-like (M26) DNA sites. Atf1 is phosphorylated by the conserved, p38-family kinase Spc1 (Sty1, Phh1) and is required for many Spc1-dependent stress responses, efficient sexual differentiation, and activation of Rec12 (Spo11)-dependent meiotic recombination hotspots like ade6-M26. METHODOLOGY/PRINCIPAL FINDINGS: We sought to define mechanisms by which Spc1 regulates Atf1 function at the ade6-M26 hotspot. The Spc1 kinase was essential for hotspot activity, but dispensable for basal recombination. Unexpectedly, a protein lacking all eleven MAPK phospho-acceptor sites and detectable phosphorylation (Atf1-11M) was fully proficient for hotspot recombination. Furthermore, tethering of Atf1 to ade6 in the chromosome by a heterologous DNA binding domain bypassed the requirement for Spc1 in promoting recombination. CONCLUSIONS/SIGNIFICANCE: The Spc1 protein kinase regulates the pathway of Atf1-promoted recombination at or before the point where Atf1 binds to chromosomes, and this pathway regulation is independent of the phosphorylation status of Atf1. Since basal recombination is Spc1-independent, the principal function of the Spc1 kinase in meiotic recombination is to correctly position Atf1-promoted recombination at hotspots along chromosomes. We also propose new hypotheses on regulatory mechanisms for shared (e.g., DNA binding) and distinct (e.g., osmoregulatory vs. recombinogenic) activities of multifunctional, stress-activated protein Atf1.",
  18430926 => "The fission yeast Schizosaccharomyces pombe senses environmental glucose through a cAMP-signaling pathway. Elevated cAMP levels activate protein kinase A (PKA) to inhibit transcription of genes involved in sexual development and gluconeogenesis, including the fbp1(+) gene, which encodes fructose-1,6-bisphosphatase. Glucose-mediated activation of PKA requires the function of nine glucose-insensitive transcription (git) genes, encoding adenylate cyclase, the PKA catalytic subunit, and seven \"upstream\" proteins required for glucose-triggered adenylate cyclase activation. We describe the cloning and characterization of the git10(+) gene, which is identical to swo1(+) and encodes the S. pombe Hsp90 chaperone protein. Glucose repression of fbp1(+) transcription is impaired by both git10(-) and swo1(-) mutant alleles of the hsp90(+) gene, as well as by chemical inhibition of Hsp90 activity and temperature stress to wild-type cells. Unlike the swo1(-) mutant alleles, the git10-201 allele supports cell growth at 37 degrees , while severely reducing glucose repression of an fbp1-lacZ reporter, suggesting a separation-of-function defect. Sequence analyses of three swo1(-) alleles and the one git10(-) allele indicate that swo1(-) mutations alter core functional domains of Hsp90, while the git10(-) mutation affects the Hsp90 central domain involved in client protein binding. These results suggest that Hsp90 plays a specific role in the S. pombe glucose/cAMP pathway.",
  19056896 => "The SAGA complex is a conserved multifunctional coactivator known to play broad roles in eukaryotic transcription. To gain new insights into its functions, we performed biochemical and genetic analyses of SAGA in the fission yeast, Schizosaccharomyces pombe. Purification of the S. pombe SAGA complex showed that its subunit composition is identical to that of Saccharomyces cerevisiae. Analysis of S. pombe SAGA mutants revealed that SAGA has two opposing roles regulating sexual differentiation. First, in nutrient-rich conditions, the SAGA histone acetyltransferase Gcn5 represses ste11(+), which encodes the master regulator of the mating pathway. In contrast, the SAGA subunit Spt8 is required for the induction of ste11(+) upon nutrient starvation. Chromatin immunoprecipitation experiments suggest that these regulatory effects are direct, as SAGA is physically associated with the ste11(+) promoter independent of nutrient levels. Genetic tests suggest that nutrient levels do cause a switch in SAGA function, as spt8Delta suppresses gcn5Delta with respect to ste11(+) derepression in rich medium, whereas the opposite relationship, gcn5Delta suppression of spt8Delta, occurs during starvation. Thus, SAGA plays distinct roles in the control of the switch from proliferation to differentiation in S. pombe through the dynamic and opposing activities of Gcn5 and Spt8.",
);


sub _add_pub_details
{
  my $schema = shift;

  my @pubs = $schema->resultset('Pub')->all();

  for my $pub (@pubs) {
    my $title = $pub_titles{$pub->pubmedid()};
    $pub->title($title) if defined $title;
    my $abstract = $pub_abstracts{$pub->pubmedid()};
    $pub->abstract($abstract) if defined $abstract;

    $pub->update();
  }
}

# populate base track database ("0_curs"), with no curation sessions (curs
# objects)
eval {
  my $schema = $test_schemas{"0_curs"};

  my $curation_load = PomCur::Track::CurationLoad->new(schema => $schema);
  my $gene_load = PomCur::Track::GeneLoad->new(schema => $schema);

  my $process =
    sub {
      $curation_load->load($curation_file);
      _add_pub_details($schema);
      $gene_load->load($genes_file);
    };

  $schema->txn_do($process);
};
if ($@) {
  die "ROLLBACK called: $@\n";
}

sub _get_curator_object
{
  my $schema = shift;
  my $email_address = shift;

  return $schema->find_with_type('Person',
                                 { networkaddress => $email_address });
}

sub _get_pub_object
{
  my $schema = shift;
  my $pubmedid = shift;

  return $schema->find_with_type('Pub', { pubmedid => $pubmedid });
}

sub make_curs_dbs
{
  my $test_case_key = shift;

  my $test_case = $test_cases{$test_case_key};
  my $schema = $test_schemas{$test_case_key};

  my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);

  my $pombe = $load_util->get_organism('Schizosaccharomyces', 'pombe');

  my $process_test_case =
    sub {
      for my $test_case_ref (@$test_case) {
        my $test_case_curs_key =
          PomCur::TestUtil::curs_key_of_test_case($test_case_ref);

        my $create_args = {
          community_curator =>
            _get_curator_object($schema, $test_case_ref->{first_contact_email}),
          curs_key => $test_case_curs_key,
          pub => _get_pub_object($schema, $test_case_ref->{pubmedid}),
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
