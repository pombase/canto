package PomCur::TestUtil;

=head1 DESCRIPTION

Utility code for testing.

=cut

use strict;
use warnings;
use Carp;
use Cwd qw(abs_path getcwd);
use File::Copy qw(copy);
use File::Copy::Recursive qw(dircopy);
use File::Temp qw(tempdir);
use File::Basename;
use YAML qw(LoadFile);
use Data::Rmap ':all';
use Clone qw(clone);

use PomCur::Config;
use PomCur::Meta::Util;
use PomCur::TrackDB;
use PomCur::Track;
use PomCur::CursDB;
use PomCur::Curs;
use PomCur::Controller::Curs;
use PomCur::Track::GeneLookup;
use PomCur::Track::CurationLoad;
use PomCur::Track::GeneLoad;
use PomCur::Track::OntologyLoad;
use PomCur::Track::OntologyIndex;
use PomCur::Track::LoadUtil;
use PomCur::DBUtil;

use Moose;

with 'PomCur::Role::MetadataAccess';

no Moose;

$ENV{POMCUR_CONFIG_LOCAL_SUFFIX} = 'test';

=head2

 Usage   : my $utils = PomCur::TestUtil->new();
 Function: Create a new TestUtil object
 Args    : none

=cut
sub new
{
  my $class = shift;
  my $arg = shift;

  my $root_dir = getcwd();

  if (!_check_dir($root_dir)) {
    $root_dir = abs_path("$root_dir/..");
    if (!_check_dir($root_dir)) {
      my $test_name = $ARGV[0];

      $root_dir = abs_path(dirname($test_name) . '/..');

      if (!_check_dir($root_dir)) {
        croak ("can't find project root directory; looked for: etc and lib\n");
      }
    }
  }

  my $self = {
    root_dir => $root_dir,
  };

  return bless $self, $class;
}

=head2

 Usage   : my $file = PomCur::TestUtil::connect_string_file($connect_string);
 Function: Return the db file name from an sqlite connect string
 Args    : $connect_string
 Return  : the file name

=cut
sub connect_string_file_name
{
  my $connect_string = shift;

  (my $db_file_name = $connect_string) =~ s/dbi:SQLite:dbname=(.*)/$1/;

  return $db_file_name;
}

=head2

 Usage   : $test_util->init_test();
 Function: set up the test environment by creating a test database and
           configuration
 Args    : $arg - pass "empty_db" to set up the tests with an empty
                  tracking database
                - pass "1_curs" to get a tracking database with one curation
                  session (initialises the curs database too)
                - pass "3_curs" to set up 3 curation sessions
                - pass nothing or "default" to set up a tracking database
                  populated with test data, but with no curation sessions

=cut
sub init_test
{
  my $self = shift;
  my $test_env_type = shift || '0_curs';
  my $args = shift || {};

  if (!defined $args->{copy_ontology_index}) {
    $args->{copy_ontology_index} = 1;
  }

  local $ENV{POMCUR_CONFIG_LOCAL_SUFFIX} = 'test';

  my $root_dir = $self->{root_dir};

  my $app_name = lc PomCur::Config::get_application_name();

  my $config = PomCur::Config->new("$root_dir/$app_name.yaml");

  my $test_config_file_name = "$root_dir/" . $config->{test_config_file};
  $config->merge_config($test_config_file_name);

  my $test_config = LoadFile($test_config_file_name)->{test_config};

  my $temp_dir = temp_dir();

  if (!exists $test_config->{test_cases}->{$test_env_type}) {
    die "no test case configured for '$test_env_type'\n";
  }

  $self->{config} = $config;

  my $data_dir = $test_config->{data_dir};

  if ($test_env_type ne 'empty_db') {
    my $track_db_file = test_track_db_name($config, $test_env_type);

    $config->{track_db_template_file} = "$root_dir/$track_db_file";
  }

  my $cwd = getcwd();
  chdir ($root_dir);
  eval {
    PomCur::Meta::Util::initialise_app($config, $temp_dir, 'test');
  };
  chdir $cwd;
  if ($@) {
    die "failed to initialise application: $@\n";
  }

  $config->merge_config("$root_dir/${app_name}_test.yaml");

  my $connect_string = $config->model_connect_string('Track');

  $self->{track_schema} = PomCur::TrackDB->new(config => $config);

  my $db_file_name = connect_string_file_name($connect_string);
  my $test_case_def = $test_config->{test_cases}->{$test_env_type};

  # copy the curs databases too
  if ($test_env_type ne 'empty_db') {
    my @test_case_curs_confs = @$test_case_def;

    for my $test_case_curs_conf (@test_case_curs_confs) {
      my $curs_key = curs_key_of_test_case($test_case_curs_conf);
      my $db_file_name = PomCur::Curs::make_db_file_name($curs_key);

      copy "$data_dir/$db_file_name", $temp_dir or die "$!";
    }
  }

  if ($args->{copy_ontology_index}) {
    my $ontology_index_file = $config->{ontology_index_file};
    my $test_ontology_index = "$data_dir/$ontology_index_file";
    my $dest_ontology_index = "$temp_dir/$ontology_index_file";

    dircopy($test_ontology_index, $dest_ontology_index)
      or die "'$!' while copying $test_ontology_index to $dest_ontology_index\n";
  }

  return (track_db_file_name => $db_file_name);
}

=head2 plack_app

 Function: make a mock Plack application for testing

=cut
sub plack_app
{
  my $self = shift;

  my $psgi_script_name = $self->root_dir() . '/script/pomcur_psgi.pl';
  my $app = Plack::Util::load_psgi($psgi_script_name);
  if ($ENV{POMCUR_DEBUG}) {
    $app = Plack::Middleware::Debug->wrap($app);
  }
  return $app;
}

=head2

 Usage   : my $test_util = PomCur::TestUtil->new();
           my $root_dir = $test_util->root_dir();
 Function: Return the root directory of the application, ie. the directory
           containing lib, etc, root, t, etc.
 Args    : none

=cut
sub root_dir
{
  my $self = shift;
  return $self->{root_dir};
}

=head2

 Usage   : my $test_util = PomCur::TestUtil->new();
           $test_util->init_test();
           my $config = $test_util->config();
 Function: Return the config object to use while testing
 Args    : none

=cut
sub config
{
  my $self = shift;
  return $self->{config};
}

=head2

 Usage   : my $test_util = PomCur::TestUtil->new();
           $test_util->init_test();
           my $schema = $test_util->track_schema();
 Function: Return the schema object of the test track database
 Args    : none

=cut
sub track_schema
{
  my $self = shift;
  return $self->{track_schema};
}

=head2 temp_dir

 Usage   : my $temp_dir_name = PomCur::TestUtil::temp_dir()
 Function: Create a temporary directory for this test
 Args    : None

=cut
sub temp_dir
{
  (my $test_name = $0) =~ s!.*/(.*)(?:\.t)?!$1!;

  return tempdir("/tmp/pomcur_test_${test_name}_$$.XXXXX", CLEANUP => 1);
}

sub _check_dir
{
  my $dir = shift;
  return -d "$dir/etc" && -d "$dir/lib";
}

=head2 test_track_db_name

 Usage   : my $db_file_name =
             PomCur::TestUtil::test_track_db_name($config, $test_name);
 Function: Return the TrackDB database file name for the given test
 Args    : $config - a PomCur::Config object
           $test_name - the name of the test from the test_config.yaml file
 Returns : The db file name

=cut
sub test_track_db_name
{
  my $config = shift;
  my $test_name = shift;

  return $config->{test_config}->{data_dir} .
    "/track_${test_name}_test_template.sqlite3";
}

=head2 make_track_test_db

 Usage   : my ($schema, $db_file_name) =
             PomCur::TestUtil::make_track_test_db($config, $test_name);
 Function: Make a copy of the empty template track database and return a schema
           object for it, or use the supplied file as the template database
 Args    : $config - a PomCur::Config object
           $test_name - the test name used to make the file name
           $track_db_template_file - the file to use as the template (optional)
 Return  : the new schema and the file name of the new database

=cut
sub make_track_test_db
{
  my $config = shift;
  my $test_name = shift;
  my $track_db_template_file = shift || $config->{track_db_template_file};

  my $track_test_db_file = test_track_db_name($config, $test_name);

  unlink $track_test_db_file;
  copy $track_db_template_file, $track_test_db_file or die "$!\n";

  return (PomCur::DBUtil::schema_for_file($config, $track_test_db_file,
                                          'Track'),
          $track_test_db_file);
}


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
  20976105 => "Silencing Mediated by the Schizosaccharomyces pombe HIRA Complex Is Dependent upon the Hpc2-Like Protein, Hip4.",
  20622008 => "A chromatin-remodeling protein is a component of fission yeast mediator.",
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
  20976105 => "BACKGROUND: HIRA (or Hir) proteins are conserved histone chaperones that function in multi-subunit complexes to mediate replication-independent nucleosome assembly. We have previously demonstrated that the Schizosaccharomyces pombe HIRA proteins, Hip1 and Slm9, form a complex with a TPR repeat protein called Hip3. Here we have identified a new subunit of this complex. METHODOLOGY/PRINCIPAL FINDINGS: To identify proteins that interact with the HIRA complex, rapid affinity purifications of Slm9 were performed. Multiple components of the chaperonin containing TCP-1 complex (CCT) and the 19S subunit of the proteasome reproducibly co-purified with Slm9, suggesting that HIRA interacts with these complexes. Slm9 was also found to interact with a previously uncharacterised protein (SPBC947.08c), that we called Hip4. Hip4 contains a HRD domain which is a characteristic of the budding yeast and human HIRA/Hir-binding proteins, Hpc2 and UBN1. Co-precipitation experiments revealed that Hip4 is stably associated with all of the other components of the HIRA complex and deletion of hip4(+) resulted in the characteristic phenotypes of cells lacking HIRA function, such as temperature sensitivity, an elongated cell morphology and hypersensitivity to the spindle poison, thiabendazole. Moreover, loss of Hip4 function alleviated the heterochromatic silencing of reporter genes located in the mating type locus and centromeres and was associated with increased levels of non-coding transcripts derived from centromeric repeat sequences. Hip4 was also found to be required for the distinct form of silencing that controls the expression of Tf2 LTR retrotransposons. CONCLUSIONS/SIGNIFICANCE: Overall, these results indicate that Hip4 is an integral component of the HIRA complex that is required for transcriptional silencing at multiple loci.",
  20622008 => "The multiprotein Mediator complex is an important regulator of RNA polymerase II-dependent genes in eukaryotic cells. In contrast to the situation in many other eukaryotes, the conserved Med15 protein is not a stable component of Mediator isolated from fission yeast. We here demonstrate that Med15 exists in a protein complex together with Hrp1, a CHD1 ATP-dependent chromatin-remodeling protein. The Med15-Hrp1 subcomplex is not a component of the core Mediator complex but can interact with the L-Mediator conformation. Deletion of med15(+) and hrp1(+) causes very similar effects on global steady-state levels of mRNA, and genome-wide analyses demonstrate that Med15 associates with a distinct subset of Hrp1-bound gene promoters. Our findings therefore indicate that Mediator may directly influence histone density at regulated promoters.",
);


my @extra_pubs = (20976105, 20622008);

sub _load_extra_pubs
{
  my $schema = shift;

  my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);

  map { $load_util->get_pub($_); } @extra_pubs;
}

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

=head2 make_base_track_db

 Usage   : my $schema =
             PomCur::TestUtil::make_base_track_db($config, $db_file_name);
 Function: Create a TrackDB for testing with basic data: curation data, sample
           genes and publication information
 Args    : $config - a PomCur::Config object (including the test properties)
           $db_file_name - the file to create
           $load_data - if non-zero or undef, load sample data into the new
                        database, otherwise just load the schema
 Returns : The TrackDB schema

=cut
sub make_base_track_db
{
  my $config = shift;
  my $db_file_name = shift;
  my $load_data = shift;

  if (!defined $load_data) {
    $load_data = 1;
  }

  my $curation_file = $config->{test_config}->{curation_spreadsheet};
  my $genes_file = $config->{test_config}->{test_genes_file};
  my $go_obo_file = $config->{test_config}->{test_go_obo_file};

  my $track_db_template_file = $config->{track_db_template_file};

  unlink $db_file_name;
  copy $track_db_template_file, $db_file_name or die "$!\n";

  my $schema = PomCur::DBUtil::schema_for_file($config, $db_file_name, 'Track');

  my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);

  if ($load_data) {
    my $organism = add_test_organism($config, $schema);

    my $curation_load = PomCur::Track::CurationLoad->new(schema => $schema);
    my $gene_load = PomCur::Track::GeneLoad->new(schema => $schema,
                                                 organism => $organism);

    my $ontology_index = PomCur::Track::OntologyIndex->new(config => $config);
    $ontology_index->initialise_index();
    my $ontology_load = PomCur::Track::OntologyLoad->new(schema => $schema);

    my $process =
      sub {
        $curation_load->load($curation_file);
        _load_extra_pubs($schema);
        _add_pub_details($schema);
        $gene_load->load($genes_file);
#        $gene_load->load('/home/kmr44/Work/pombe/sysID2product.txt');
        $ontology_load->load($go_obo_file, $ontology_index);
#        $ontology_load->load('/home/kmr44/Work/perl/go-perl/gene_ontology_ext.obo', $ontology_index);
      };

    $schema->txn_do($process);

    $ontology_index->finish_index();
  }

  return $schema;
}

=head2 add_test_organism

 Usage   : my $organism = PomCur::TestUtil::add_test_organism($config, $schema);
 Function: Create a test Organism
 Args    : $config - a PomCur::Config object
           $schema - the TrackDB schema object
 Returns :

=cut
sub add_test_organism
{
  my $config = shift;
  my $schema = shift;

  my $test_config = $config->{test_config};
  my $organism_config = $test_config->{organism};
  my $load_util = PomCur::Track::LoadUtil->new(schema => $schema);

  return $load_util->get_organism($organism_config->{genus},
                                  $organism_config->{species},
                                  $organism_config->{taxonid});
}

=head2 curs_key_of_test_case

 Usage   : my $curs_key = PomCur::TestUtil::curs_key_of_test_case($test_case);
 Function: Get the curs_key to use for the given curs test case definition
 Args    : $test_case - the test case definition
 Return  :

=cut
sub curs_key_of_test_case
{
  my $test_case_def = shift;

  return $test_case_def->{curs_key};
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

sub _load_curs_db_data
{
  my $config = shift;
  my $trackdb_schema = shift;
  my $cursdb_schema = shift;
  my $curs_config = shift;

  my $gene_lookup = PomCur::Track::GeneLookup->new(config => $config,
                                                   schema => $trackdb_schema);

  set_metadata($cursdb_schema, 'submitter_email',
               $curs_config->{submitter_email});
  set_metadata($cursdb_schema, 'submitter_name',
               $curs_config->{submitter_name});

  for my $gene_identifier (@{$curs_config->{genes}}) {
    my $result = $gene_lookup->lookup([$gene_identifier]);
    my @found = @{$result->{found}};
    if (@found != 1) {
      die "Expected 1 result for $gene_identifier not ", scalar(@found)
    }
    my $gene_info = $found[0];

    my $new_gene =
      PomCur::Controller::Curs::_create_gene($cursdb_schema, $result);

    my $current_config_gene = $curs_config->{current_gene};
    if ($gene_identifier eq $current_config_gene) {
      set_metadata($cursdb_schema, 'current_gene_id',
                   $new_gene->gene_id());
    }
  }

  for my $annotation (@{$curs_config->{annotations}}) {
    my %create_args = %{_process_data($cursdb_schema, $annotation)};

    $create_args{creation_date} = '2010-01-02';

    # save the args that are arrays and set them after creation to cope with
    # many-many relations
    my %array_args = ();

    for my $key (keys %create_args) {
      if (ref $create_args{$key} eq 'ARRAY') {
        $array_args{$key} = $create_args{$key};
        delete $create_args{$key};
      }
    }

    my $new_annotation =
      $cursdb_schema->create_with_type('Annotation', { %create_args });

    for my $key (keys %array_args) {
      my $method = "set_$key";
      $new_annotation->$method(@{$array_args{$key}});
    }
  }
}

sub _replace_object
{
  my $schema = shift;
  my $class_name = shift;
  my $lookup_field_name = shift;
  my $value = shift;
  my $return_object = shift;

  my $object = $schema->find_with_type($class_name,
                                       {
                                         $lookup_field_name, $value
                                       });

  if ($return_object) {
    return $object;
  } else {
    return PomCur::DB::id_of_object($object);
  }
}

sub _process_data
{
  my $cursdb_schema = shift;
  my $config_data_ref = shift;

  my $data = clone($config_data_ref);

  my $field_name = $1;
  my $class_name = $2;
  my $lookup_field_name = $3;

  rmap_to {
    # change 'field_name(class_name:field_name)' => [value, value] to:
    # 'field_name' => [object_id, object_id] by looking up the object
    my %tmp_hash = %$_;
    while (my ($key, $value) = each %tmp_hash) {
      if ($key =~ /([^:]+)\((.*):(.*)\)/) {
        my $field_name = $1;
        my $class_name = $2;
        my $lookup_field_name = $3;
        delete $_->{$key};
        my $type_name = PomCur::DB::table_name_of_class($class_name);

        if (ref $value eq 'ARRAY') {
          $_->{$field_name} = [map {
            _replace_object($cursdb_schema, $class_name,
                            $lookup_field_name, $_, 1);
          } @$value];
        } else {
          $_->{$field_name} =
            _replace_object($cursdb_schema,
                            $class_name, $lookup_field_name, $value);
        }
      }
    }
  } HASH, $data;

  return $data;
}

=head2 make_curs_db

 Usage   : PomCur::TestUtil::make_curs_db($config, $curs_config,
                                          $trackdb_schema);
 Function: Make a curs database for the given $curs_config and update the
           TrackDB given by $trackdb_schema.  See the test_config.yaml file
           for example curs test case configurations.
 Args    : $config - a PomCur::Config object that includes the test properties
           $curs_config - the configuration for this curs
           $trackdb_schema - the TrackDB
 Returns : ($curs_schema, $cursdb_file_name) - A CursDB object for the new db,
           and its file name - die()s on failure

=cut
sub make_curs_db
{
  my $config = shift;
  my $curs_config = shift;
  my $trackdb_schema = shift;
  my $load_util = shift;

  my $organism_conf = $config->{test_config}->{organism};

  my $pombe = $load_util->get_organism($organism_conf->{genus},
                                       $organism_conf->{species},
                                       $organism_conf->{taxonid});

  my $test_case_curs_key =
    PomCur::TestUtil::curs_key_of_test_case($curs_config);

  my $create_args = {
    community_curator =>
      _get_curator_object($trackdb_schema, $curs_config->{first_contact_email}),
    curs_key => $test_case_curs_key,
    pub => _get_pub_object($trackdb_schema, $curs_config->{pubmedid}),
  };

  my $curs_object = $trackdb_schema->create_with_type('Curs', $create_args);

  my $curs_file_name =
    PomCur::Curs::make_long_db_file_name($config, $test_case_curs_key);
  unlink $curs_file_name;

  my ($cursdb_schema, $cursdb_file_name) =
    PomCur::Track::create_curs_db($config, $curs_object);

  if (exists $curs_config->{submitter_email}) {
    $cursdb_schema->txn_do(
      sub {
        _load_curs_db_data($config, $trackdb_schema, $cursdb_schema,
                           $curs_config);
      });
  }

  return ($cursdb_schema, $cursdb_file_name);
}


1;
