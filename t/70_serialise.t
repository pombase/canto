use strict;
use warnings;
use Test::Deep;

use Test::More tests => 4;

use Data::Compare;

use JSON;

use PomCur::TestUtil;
use PomCur::TrackDB;
use PomCur::Track::Serialise;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = PomCur::TrackDB->new(config => $config);

my $abstract =
 qr/In the fission yeast, Schizosaccharomyces pombe, synaptonemal complexes/;
my $expected_curation_session =
  {
    genes => {
      'SPCC576.16c' => {
        primary_name => 'wtf22',
        product => 'wtf element Wtf22',
        organism => 'Schizosaccharomyces pombe',
        annotations => [],
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
            with_gene => "SPCC576.16c"
          } ],
        synonyms => ['ssm4'],
      },
      'SPCC63.05' => {
        primary_name => undef,
        product => 'TAP42 family protein involved in TOR signalling (predicted)',
        organism => 'Schizosaccharomyces pombe',
        annotations => [
          {
            type => 'genetic_interaction',
            publication => 'PMID:19756689',
            status => 'new',
            creation_date => "2010-01-02",
            evidence_code => 'Synthetic Haploinsufficiency',
            interacting_genes => [
              {
                primary_identifier => 'SPBC14F5.07',
              },
              {
                primary_identifier => 'SPAC27D7.13c',
              }
            ]
          },
          {
            type => 'fission_yeast_phenotype',
            status => 'new',
            creation_date => "2010-01-02",
            evidence_code => 'MIU',
            publication => 'PMID:19756689',
            term_ontid => 'PP:00004',
          },
        ],
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
  };


my $curs_schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0007');

my $curs_json = PomCur::Curs::Serialise::json($curs_schema, { dump_all => 1 });
my $curs_ref = decode_json($curs_json);

cmp_deeply($curs_ref, $expected_curation_session);

my $track_json = PomCur::Track::Serialise::json($config, $track_schema, { dump_all => 1});
my $track_ref = decode_json($track_json);

my @expected_pubs =
  qw"PMID:16641370 PMID:17304215 PMID:18426916 PMID:18430926 PMID:18556659
     PMID:19037101 PMID:19041767 PMID:19056896 PMID:19160458 PMID:19211838
     PMID:19351719 PMID:19436749 PMID:19627505 PMID:19664060 PMID:19686603
     PMID:19756689 PMID:20622008 PMID:20870879 PMID:20976105 PMID:7518718
     PMID:7958849 PMID:10467002";
my %expected_pubs = ();
@expected_pubs{@expected_pubs} = (ignore()) x @expected_pubs;

cmp_deeply($track_ref,
           {
             publications => \%expected_pubs,
             curation_sessions => ignore(),
             'people' => {
               'dom@genetics.med.harvard.edu' => {
                 'password' => 'dom@genetics.med.harvard.edu',
                 'lab' => 'Winston Lab',
                 'name' => 'Dom Helmlinger',
                 'role' => 'user'
               },
               'Pascale.Beauregard@umontreal.ca' => {
                 'password' => 'Pascale.Beauregard@umontreal.ca',
                 'lab' => 'Rokeach Lab',
                 'name' => 'Pascale Beauregard',
                 'role' => 'user'
               },
               'peter.espenshade@jhmi.edu' => {
                 'password' => 'peter.espenshade@jhmi.edu',
                 'lab' => 'Espenshade Lab',
                 'name' => 'Peter Espenshade',
                 'role' => 'user'
               },
               'kevin.hardwick@ed.ac.uk' => {
                 'password' => 'kevin.hardwick@ed.ac.uk',
                 'lab' => 'Hardwick Lab',
                 'name' => 'Kevin Hardwick',
                 'role' => 'user'
               },
               'hoffmacs@bc.edu' => {
                 'password' => 'hoffmacs@bc.edu',
                 'lab' => 'Hoffman Lab',
                 'name' => 'Charles Hoffman',
                 'role' => 'user'
               },
               'fred.winston@genetics.med.harvard.edu' => {
                 'password' => 'fred.winston@genetics.med.harvard.edu',
                 'lab' => 'Winston Lab',
                 'name' => 'Fred Winston',
                 'role' => 'user'
               },
               'h.yamano@mcri.ac.uk' => {
                 'password' => 'h.yamano@mcri.ac.uk',
                 'lab' => 'Yamano Lab',
                 'name' => 'Hiro Yamano',
                 'role' => 'user'
               },
               'test.user@pombase.org' => {
                 'password' => 'test.user@pombase.org',
                 'lab' => 'User Lab',
                 'name' => 'Test User',
                 'role' => 'user'
               },
               'Mary.Porter-Goff@umassmed.edu' => {
                 'password' => 'Mary.Porter-Goff@umassmed.edu',
                 'lab' => 'Rhind Lab',
                 'name' => 'Mary Porter-Goff',
                 'role' => 'user'
               },
               'Ken.Sawin@ed.ac.uk' => {
                 'password' => 'Ken.Sawin@ed.ac.uk',
                 'lab' => 'Sawin Lab',
                 'name' => 'Ken Sawin',
                 'role' => 'user'
               },
               'val@sanger.ac.uk' => {
                 'password' => 'val@sanger.ac.uk',
                 'lab' => undef,
                 'name' => 'Val Wood',
                 'role' => 'admin'
               },
               'mah79@cam.ac.uk' => {
                 'password' => 'mah79@cam.ac.uk',
                 'lab' => undef,
                 'name' => 'Midori Harris',
                 'role' => 'admin'
               },
               'henar@usal.es' => {
                 'password' => 'henar@usal.es',
                 'lab' => 'Valdivieso Lab',
                 'name' => 'Henar Valdivieso',
                 'role' => 'user'
               },
               'iwasaki@tsurumi.yokohama-cu.ac.jp' => {
                 'password' => 'iwasaki@tsurumi.yokohama-cu.ac.jp',
                 'lab' => "\x{e5}\x{b2}\x{a9}\x{e5}\x{b4}\x{8e}\x{e3}\x{81}\x{b2}\x{e3}\x{82}\x{8d}\x{e3}\x{81}\x{97} Lab",
                 'name' => "\x{e5}\x{b2}\x{a9}\x{e5}\x{b4}\x{8e}\x{e3}\x{81}\x{b2}\x{e3}\x{82}\x{8d}\x{e3}\x{81}\x{97}",
                 'role' => 'user'
               },
               'Nicholas.Willis@umassmed.edu' => {
                 'password' => 'Nicholas.Willis@umassmed.edu',
                 'lab' => 'Rhind Lab',
                 'name' => 'Nicholas Willis',
                 'role' => 'user'
               },
               'stuart.macneill@st-andrews.ac.uk' => {
                 'password' => 'stuart.macneill@st-andrews.ac.uk',
                 'lab' => 'Macneill Lab',
                 'name' => 'Stuart Macneill',
                 'role' => 'user'
               },
               'nick.rhind@umassmed.edu' => {
                 'password' => 'nick.rhind@umassmed.edu',
                 'lab' => 'Rhind Lab',
                 'name' => 'Nick Rhind',
                 'role' => 'user'
               },
               'Luis.Rokeach@umontreal.ca' => {
                 'password' => 'Luis.Rokeach@umontreal.ca',
                 'lab' => 'Rokeach Lab',
                 'name' => 'Luis Rokeach',
                 'role' => 'user'
               },
               'wahlswaynep@uams.edu' => {
                 'password' => 'wahlswaynep@uams.edu',
                 'lab' => 'Wahls Lab',
                 'name' => 'Wayne Wahls',
                 'role' => 'user'
               },
               'John.Burg@jhmi.edu' => {
                 'password' => 'John.Burg@jhmi.edu',
                 'lab' => 'Espenshade Lab',
                 'name' => 'John Burg',
                 'role' => 'user'
               },
               'a.nilsson@warwick.ac.uk' => {
                 'password' => 'a.nilsson@warwick.ac.uk',
                 'lab' => undef,
                 'name' => 'Antonia Nilsson',
                 'role' => 'admin',
               },
             },
             labs => {
               'Wahls Lab' => {
                 'head' => 'Wayne Wahls'
               },
               'Sawin Lab' => {
                 'head' => 'Ken Sawin'
               },
               'Macneill Lab' => {
                 'head' => 'Stuart Macneill'
               },
               'Rokeach Lab' => {
                 'head' => 'Luis Rokeach'
               },
               'Rhind Lab' => {
                 'head' => 'Nick Rhind'
               },
               'Hoffman Lab' => {
                 'head' => 'Charles Hoffman'
               },
               'Espenshade Lab' => {
                 'head' => 'Peter Espenshade'
               },
               'User Lab' => {
                 'head' => 'Test User'
               },
               'Valdivieso Lab' => {
                 'head' => 'Henar Valdivieso'
               },
               'Yamano Lab' => {
                 'head' => 'Hiro Yamano'
               },
               'Hardwick Lab' => {
                 'head' => 'Kevin Hardwick'
               },
               "\x{e5}\x{b2}\x{a9}\x{e5}\x{b4}\x{8e}\x{e3}\x{81}\x{b2}\x{e3}\x{82}\x{8d}\x{e3}\x{81}\x{97} Lab" => {
                 'head' => "\x{e5}\x{b2}\x{a9}\x{e5}\x{b4}\x{8e}\x{e3}\x{81}\x{b2}\x{e3}\x{82}\x{8d}\x{e3}\x{81}\x{97}"
               },
               'Winston Lab' => {
                 'head' => 'Fred Winston'
               }
             }
           }
         );

my %curation_sessions = %{$track_ref->{curation_sessions}};
is (keys %curation_sessions, 2);

my $curation_session = $curation_sessions{aaaa0007};

cmp_deeply($curation_session, $expected_curation_session);
