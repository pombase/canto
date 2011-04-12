use strict;
use warnings;
use Test::Deep;

use Test::More tests => 3;

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

my @expected_pubs =
  qw{PMID:16641370 PMID:17304215 PMID:18426916 PMID:18430926 PMID:18556659
     PMID:19037101 PMID:19041767 PMID:19056896 PMID:19160458 PMID:19211838
     PMID:19351719 PMID:19436749 PMID:19627505 PMID:19664060 PMID:19686603
     PMID:19756689 PMID:20622008 PMID:20870879 PMID:20976105 PMID:7518718
     PMID:7958849};
my %expected_pubs = ();
@expected_pubs{@expected_pubs} = (ignore()) x @expected_pubs;

cmp_deeply($ref,
           {
             publications => \%expected_pubs,
             curation_sessions => ignore(),
           }
           );

my @curation_sessions = @{$ref->{curation_sessions}};
is (@curation_sessions, 2);

my $abstract =
 qr/In the fission yeast, Schizosaccharomyces pombe, synaptonemal complexes/;

my $curation_session = $curation_sessions[1];
cmp_deeply($curation_session,
          {
            genes => {
              'SPCC576.16c' => {
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
              'SPAC27D7.13c' => {
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
              'SPBC14F5.07' => {
                primary_name => 'doa10',
                product => 'ER-localized ubiquitin ligase Doa10 (predicted)',
                organism => 'Schizosaccharomyces pombe',
                annotations => [
                  {
                    evidence_code => "IPI",
                    creation_date => "2010-01-02",
                    term_ontid => "GO:0034763",
                    status => "new",
                    type => "biological_process",
                    publication => 'PMID:19756689',
                    with_gene => "SPCC63.05"
                    } ],
                synonyms => ['ssm4'],
              },
              'SPCC63.05' => {
                primary_name => undef,
                product => 'TAP42 family protein involved in TOR signalling (predicted)',
                organism => 'Schizosaccharomyces pombe',
                annotations => [],
                synonyms => [],
              },
            },
            publications => {
              'PMID:19756689' => {
                title => 'SUMOylation is required for normal development of linear elements and wild-type meiotic recombination in Schizosaccharomyces pombe.',
                abstract => re($abstract),
              }
            },
            metadata => {
              submitter_email => 'Ken.Sawin@ed.ac.uk',
              submitter_name =>'Ken Sawin',
              first_contact_email => 'Ken.Sawin@ed.ac.uk',
              first_contact_name => 'Ken Sawin',
              curs_key => 'aaaa0007',
              current_gene_id => 'SPCC576.16c',
              curation_pub_id => 'PMID:19756689',
            },
            organisms => {
              4896 => {
                full_name => 'Schizosaccharomyces pombe',
              }
            },
          },
          );
