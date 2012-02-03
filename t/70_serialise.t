use strict;
use warnings;
use Test::Deep;

use Test::More tests => 6;

use Data::Compare;
use Clone qw(clone);
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
my $full_expected_curation_session =
  {
    genes => {
      'Schizosaccharomyces pombe SPCC576.16c' => {
        uniquename => 'SPCC576.16c',
        primary_name => 'wtf22',
        product => 'wtf element Wtf22',
        organism => 'Schizosaccharomyces pombe',
        annotations => [],
        synonyms => [],
      },
      'Schizosaccharomyces pombe SPAC27D7.13c' => {
        uniquename => 'SPAC27D7.13c',
        primary_name => 'ssm4',
        product => 'p150-Glued',
        organism => 'Schizosaccharomyces pombe',
        annotations => [
          {
            evidence_code => "IMP",
            creation_date => "2010-01-02",
            term => "GO:0055085",
            status => "new",
            type => "biological_process",
            publication => 'PMID:19756689',
            term_suggestion => {
                 name => 'miscellaneous transmembrane transport',
                 definition =>
                   'The process in which miscellaneous stuff is transported from one side of a membrane to the other.',
            },
          } ],
        synonyms => ['SPAC637.01c'],
      },
      'Schizosaccharomyces pombe SPBC14F5.07' => {
        uniquename => 'SPBC14F5.07',
        primary_name => 'doa10',
        product => 'ER-localized ubiquitin ligase Doa10 (predicted)',
        organism => 'Schizosaccharomyces pombe',
        annotations => [
          {
            evidence_code => "IPI",
            creation_date => "2010-01-02",
            term => "GO:0034763",
            status => "new",
            type => "biological_process",
            publication => 'PMID:19756689',
            with_gene => "SPCC576.16c",
            annotation_extension => 'exists_during(GO:0051329)|has_substrate(GeneDB_Spombe:SPBC1105.11c),requires_feature(Pfam:PF00564)',
          },
          {
            evidence_code => 'IDA',
            creation_date => '2010-01-02',
            status => 'new',
            type => 'molecular_function',
            publication => 'PMID:19756689',
            term => 'GO:0022857'
          }
        ],
        synonyms => ['ssm4'],
      },
      'Schizosaccharomyces pombe SPCC63.05' => {
        uniquename => 'SPCC63.05',
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
            evidence_code => 'IDA',
            publication => 'PMID:19756689',
            term => 'FYPO:0000004',
          },
          {
            type => 'PSI-MOD',
            status => 'new',
            creation_date => "2010-01-02",
            evidence_code => 'ISS',
            publication => 'PMID:19756689',
            term => 'PSI-MOD:00017',
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
      curation_pub_id => 'PMID:19756689',
      term_suggestion_count => 1,
    },
    organisms => {
      4896 => {
        full_name => 'Schizosaccharomyces pombe',
      }
    },
  };

my $small_expected_curation_session = clone $full_expected_curation_session;
$small_expected_curation_session->{publications}->{'PMID:19756689'} = {};
my $genes_ref = $small_expected_curation_session->{genes};
map {
  delete $genes_ref->{$_}->{product};
  delete $genes_ref->{$_}->{synonyms};
  delete $genes_ref->{$_}->{primary_name};
} keys %{$small_expected_curation_session->{genes}};

my %expected_people = (
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
);

my %expected_labs = (

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
  },
);

my @expected_pubs =
  qw"PMID:16641370 PMID:17304215 PMID:18426916 PMID:18430926 PMID:18556659
     PMID:19037101 PMID:19041767 PMID:19056896 PMID:19160458 PMID:19211838
     PMID:19351719 PMID:19436749 PMID:19627505 PMID:19664060 PMID:19686603
     PMID:19756689 PMID:20622008 PMID:20870879 PMID:20976105 PMID:7518718
     PMID:7958849 PMID:10467002";
my %expected_pubs = ();
@expected_pubs{@expected_pubs} = (ignore()) x @expected_pubs;

my %extra_curs_statuses = (
        annotation_status => PomCur::Controller::Curs::CURATION_IN_PROGRESS,
        session_genes_count => 4,
        session_term_suggestions_count => 1,
);

my $full_expected_track_data =
  {
    publications => \%expected_pubs,
    curation_sessions => {
      aaaa0007 => {
        %extra_curs_statuses,
        %$full_expected_curation_session,
      },
      aaaa0006 => ignore(),
    },
    people => \%expected_people,
    labs => \%expected_labs,
  };

my $small_expected_track_data =
  {
    publications => \%expected_pubs,
    curation_sessions => {
      aaaa0007 => {
        %extra_curs_statuses,
        %$small_expected_curation_session,
      },
      aaaa0006 => ignore(),
    },
    people => \%expected_people,
    labs => \%expected_labs,
  };


my $curs_schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0007');

{
  my $curs_json = PomCur::Curs::Serialise::json($curs_schema, { dump_all => 1 });
  my $curs_ref = decode_json($curs_json);

  cmp_deeply($curs_ref, $full_expected_curation_session);
}

{
  my $curs_json = PomCur::Curs::Serialise::json($curs_schema, { dump_all => 0 });
  my $curs_ref = decode_json($curs_json);

  cmp_deeply($curs_ref, $small_expected_curation_session);
}

{
  my $curs_json = PomCur::Curs::Serialise::json($curs_schema);
  my $curs_ref = decode_json($curs_json);

  cmp_deeply($curs_ref, $small_expected_curation_session);
}

my $track_json = PomCur::Track::Serialise::json($config, $track_schema, { dump_all => 1});
my $track_ref = decode_json($track_json);

cmp_deeply($track_ref, $full_expected_track_data);

my %curation_sessions = %{$track_ref->{curation_sessions}};
is (keys %curation_sessions, 2);

my $curation_session = $curation_sessions{aaaa0007};

cmp_deeply($curation_session, $full_expected_curation_session);
