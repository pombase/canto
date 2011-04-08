use strict;
use warnings;
use Test::More tests => 7;

use Data::Compare;

use JSON;

use PomCur::TestUtil;
use PomCur::TrackDB;
use PomCur::Track::Serialise;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $schema = PomCur::TrackDB->new(config => $config);

my $json = PomCur::Track::Serialise::json($config, $schema);
my $ref = decode_json($json);

my @curation_sessions = @{$ref->{curation_sessions}};
is (@curation_sessions, 2);

my $abstract = q{In the fission yeast, Schizosaccharomyces pombe, synaptonemal complexes (SCs) are not formed during meiotic prophase. However, structures resembling the axial elements of SCs, the so-called linear elements (LinEs) appear. By in situ immunostaining, we found Pmt3 (S. pombe's SUMO protein) transiently along LinEs, suggesting that SUMOylation of some component(s) of LinEs occurs during meiosis. Mutation of the SUMO ligase Pli1 caused aberrant LinE formation and reduced genetic recombination indicating a role for SUMOylation of LinEs for the regulation of meiotic recombination. Western blot analysis of TAP-tagged Rec10 demonstrated that there is a Pli1-dependent posttranslational modification of this protein, which is a major LinE component and a distant homolog of the SC protein Red1. Mass spectrometry (MS) analysis revealed that Rec10 is both phosphorylated and ubiquitylated, but no evidence for SUMOylation of Rec10 was found. These findings indicate that the regulation of LinE and Rec10 function is modulated by Pli1-dependent SUMOylation of LinE protein(s) which directly or indirectly regulates Rec10 modification. On the side, MS analysis confirmed the interaction of Rec10 with the known LinE components Rec25, Rec27, and Hop1 and identified the meiotically upregulated protein Mug20 as a novel putative LinE-associated protein.};

my $curation_session = $curation_sessions[1];
is_deeply($curation_session,
          { genes => [
              { primary_identifier => 'SPCC576.16c',
                primary_name => 'wtf22',
                product => 'wtf element Wtf22',
                organism => 'Schizosaccharomyces pombe',
                annotations => [
                  {
                    evidence_code => "MIU",
                    creation_date => "2010-01-02",
                    term_ontid => "PP:00004",
                    status => "new",
                    type => "phenotype",
                    publication => 'PMID:19756689'
                    } ],
                synonyms => [],
              },
            { primary_identifier => 'SPAC27D7.13c',
              primary_name => 'ssm4',
              product => 'p150-Glued',
              organism => 'Schizosaccharomyces pombe',
              annotations => [
                {
                  evidence_code => "IMP",
                  creation_date => "2010-01-02",
                  term_ontid => "GO:0055085",
                  status => "new",
                  type => "biological_process",
                  publication => 'PMID:19756689'
                  } ],
              synonyms => ['SPAC637.01c'],
            },
            ],
            publications => [
              {
                uniquename => 'PMID:19756689',
                title => 'SUMOylation is required for normal development of linear elements and wild-type meiotic recombination in Schizosaccharomyces pombe.',
                abstract => $abstract,
              }
            ],
            metadata => {
              submitter_email => 'Ken.Sawin@ed.ac.uk',
              submitter_name =>'Ken Sawin',
              first_contact_email => 'Ken.Sawin@ed.ac.uk',
              first_contact_name => 'Ken Sawin',
              curs_key => 'aaaa0007',
              current_gene_id => 'SPCC576.16c',
              curation_pub_id => 'PMID:19756689',
            },
            organisms => [
              {
                taxonid => 4896,
                full_name => 'Schizosaccharomyces pombe',
              }
            ],
          },
          );


my @publications = @{$curation_session->{publications}};
is (@publications, 1);
is ($publications[0]->{uniquename}, 'PMID:19756689');
like ($publications[0]->{abstract}, qr/SUMOylation/);

my @organisms = @{$curation_session->{organisms}};
is (@organisms, 1);
is ($organisms[0]->{full_name}, "Schizosaccharomyces pombe");

