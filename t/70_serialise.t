use strict;
use warnings;
use Test::Deep;

use Test::More tests => 6;

use Clone qw(clone);
use JSON;

use utf8;

use Digest::SHA qw(sha1_base64);

use Canto::TestUtil;
use Canto::TrackDB;
use Canto::Track::Serialise;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = Canto::TrackDB->new(config => $config);

my %extra_curs_statuses = (
        annotation_status => Canto::Controller::Curs::CURATION_IN_PROGRESS,
        annotation_status_datestamp => '2012-02-15 13:45:00',
        session_genes_count => 4,
        session_unknown_conditions_count => 1,
        session_term_suggestions_count => 1,
);

my $abstract =
 qr/In the fission yeast, Schizosaccharomyces pombe, synaptonemal complexes/;
my $full_expected_curation_session =
  {
    genes => {
      'Schizosaccharomyces pombe SPAC27D7.13c' => {
        uniquename => 'SPAC27D7.13c',
        organism => 'Schizosaccharomyces pombe',
      },
      'Schizosaccharomyces pombe SPBC14F5.07' => {
        uniquename => 'SPBC14F5.07',
        organism => 'Schizosaccharomyces pombe',
      },
      'Schizosaccharomyces pombe SPCC63.05' => {
        uniquename => 'SPCC63.05',
        organism => 'Schizosaccharomyces pombe',
      },
      'Schizosaccharomyces pombe SPCC576.16c' => {
        uniquename => 'SPCC576.16c',
        organism => 'Schizosaccharomyces pombe',
      }
    },
    alleles => {
      'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-1' => {
        primary_identifier => 'SPAC27D7.13c:aaaa0007-1',
        name => 'ssm4delta',
        description => 'deletion',
        allele_type => 'deletion',
        gene => 'Schizosaccharomyces pombe SPAC27D7.13c'
      },
      'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-2' => {
        description => 'G40A,K43E',
        allele_type => 'amino_acid_mutation',
        gene => 'Schizosaccharomyces pombe SPAC27D7.13c',
        primary_identifier => 'SPAC27D7.13c:aaaa0007-2',
        name => 'ssm4KE'
      },
      'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-3' => {
        description => 'del_100-200',
        gene => 'Schizosaccharomyces pombe SPAC27D7.13c',
        allele_type => 'partial_nucleotide_deletion',
        primary_identifier => 'SPAC27D7.13c:aaaa0007-3',
        name => 'ssm4-D4'
      },
      'Schizosaccharomyces pombe SPCC63.05:aaaa0007-1' => {
        gene => 'Schizosaccharomyces pombe SPCC63.05',
        allele_type => 'deletion',
        description => 'deletion',
        name => 'SPCC63.05delta',
        primary_identifier => 'SPCC63.05:aaaa0007-1'
      },
      'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-4' => {
        description => 'del_200-300',
        gene => 'Schizosaccharomyces pombe SPAC27D7.13c',
        allele_type => 'partial_nucleotide_deletion',
        primary_identifier => 'SPAC27D7.13c:aaaa0007-4'
      }
    },
    genotypes => {
      'aaaa0007-genotype-test-1' => {
        'name' => 'h+ SPCC63.05delta ssm4KE',
        alleles => [
          {
            id => 'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-1',
          },
          {
            id => 'Schizosaccharomyces pombe SPCC63.05:aaaa0007-1',
          },
        ],
      },
      'aaaa0007-genotype-test-2' => {
        alleles => [
          {
            id => 'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-3',
            expression => 'Knockdown',
         },
        ],
      },
    },
    annotations => [
      {
        evidence_code => "IMP",
        creation_date => "2010-01-02",
        term => "GO:0055085",
        status => "new",
        type => "biological_process",
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@pombase.org',
          community_curated => JSON::XS::false,
        },
        term_suggestion => {
          name => 'miscellaneous transmembrane transport',
          definition =>
            'The process in which miscellaneous stuff is transported from one side of a membrane to the other.',
        },
        gene => 'Schizosaccharomyces pombe SPAC27D7.13c',
      },
      {
        evidence_code => "IPI",
        creation_date => "2010-01-02",
        term => "GO:0034763",
        status => "new",
        type => "biological_process",
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@pombase.org',
          community_curated => JSON::XS::false,
        },
        with_gene => "SPCC576.16c",
        annotation_extension => 'annotation_extension=exists_during(GO:0051329),annotation_extension=has_substrate(PomBase:SPBC1105.11c),annotation_extension=requires_feature(Pfam:PF00564),residue=T31,residue=T586(T586,X123),qualifier=NOT,condition=PECO:0000012,allele=SPAC9.02cdelta(deletion)|annotation_extension=exists_during(GO:0051329),has_substrate(PomBase:SPBC1105.11c)',
        gene => 'Schizosaccharomyces pombe SPBC14F5.07',
      },
      {
        evidence_code => 'IDA',
        creation_date => '2010-01-02',
        status => 'new',
        type => 'molecular_function',
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@pombase.org',
          community_curated => JSON::XS::false,
        },
        term => 'GO:0022857',
        gene => 'Schizosaccharomyces pombe SPBC14F5.07',
      },
      {
        type => 'genetic_interaction',
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@pombase.org',
          community_curated => JSON::XS::false,
        },
        status => 'new',
        creation_date => "2010-01-02",
        evidence_code => 'Synthetic Haploinsufficiency',
        gene => 'Schizosaccharomyces pombe SPCC63.05',
        interacting_genes => [
          'Schizosaccharomyces pombe SPBC14F5.07',
        ],
      },
      {
        type => 'genetic_interaction',
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@pombase.org',
          community_curated => JSON::XS::false,
        },
        status => 'new',
        creation_date => "2010-01-02",
        evidence_code => 'Far Western',
        gene => 'Schizosaccharomyces pombe SPCC63.05',
        interacting_genes => [
          'Schizosaccharomyces pombe SPAC27D7.13c',
        ]
      },
      {
        status => 'new',
        term => 'FYPO:0000013',
        evidence_code => 'Epitope-tagged protein immunolocalization experiment data',
        creation_date => '2010-01-02',
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@pombase.org',
          community_curated => JSON::XS::false,
        },
        type => 'phenotype',
        conditions => [
          'PECO:0000137',
          'rich medium',
        ],
        genotype => 'aaaa0007-genotype-test-1',
      },
      {
        evidence_code => 'Co-immunoprecipitation experiment',
        creation_date => '2010-01-02',
        genotype => 'aaaa0007-genotype-test-2',
        status => 'new',
        type => 'phenotype',
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@pombase.org',
          community_curated => JSON::XS::false,
        },
        term => 'FYPO:0000017'
      },
      {
        type => 'post_translational_modification',
        status => 'new',
        creation_date => "2010-01-02",
        evidence_code => 'ISS',
        publication => 'PMID:19756689',
        curator => {
          name => 'Another Testperson',
          email => 'a.n.other.testperson@pombase.org',
          community_curated => JSON::XS::true,
        },
        term => 'MOD:01157',
        gene => 'Schizosaccharomyces pombe SPCC63.05',
      },
    ],
    publications => {
      'PMID:19756689' => {
        title => 'SUMOylation is required for normal development of linear elements and wild-type meiotic recombination in Schizosaccharomyces pombe.',
        abstract => re($abstract),
      },
    },
    metadata => {
      canto_session => 'aaaa0007',
      curation_pub_id => 'PMID:19756689',
      term_suggestion_count => 1,
      unknown_conditions_count => 1,
      accepted_timestamp => '2012-02-15 13:45:00',
      curation_in_progress_timestamp => '2012-02-15 13:45:00',
      session_created_timestamp => '2012-02-15 13:45:00',
      %extra_curs_statuses,
    },
    organisms => {
      4896 => {
        full_name => 'Schizosaccharomyces pombe',
      },
    },
  };

my $small_expected_curation_session = clone $full_expected_curation_session;
$small_expected_curation_session->{publications}->{'PMID:19756689'} = {};

my %expected_people = (
  'dom@genetics.med.harvard.edu' => {
    'password' => sha1_base64('dom@genetics.med.harvard.edu'),
    'lab' => 'Winston Lab',
    'name' => 'Dom Helmlinger',
    'role' => 'user'
  },
  'Pascale.Beauregard@umontreal.ca' => {
    'password' => sha1_base64('Pascale.Beauregard@umontreal.ca'),
    'lab' => 'Rokeach Lab',
    'name' => 'Pascale Beauregard',
    'role' => 'user'
  },
  'peter.espenshade@jhmi.edu' => {
    'password' => sha1_base64('peter.espenshade@jhmi.edu'),
    'lab' => 'Espenshade Lab',
    'name' => 'Peter Espenshade',
    'role' => 'user'
  },
  'kevin.hardwick@ed.ac.uk' => {
    'password' => sha1_base64('kevin.hardwick@ed.ac.uk'),
    'lab' => 'Hardwick Lab',
    'name' => 'Kevin Hardwick',
    'role' => 'user'
  },
  'hoffmacs@bc.edu' => {
    'password' => sha1_base64('hoffmacs@bc.edu'),
    'lab' => 'Hoffman Lab',
    'name' => 'Charles Hoffman',
    'role' => 'user'
  },
  'fred.winston@genetics.med.harvard.edu' => {
    'password' => sha1_base64('fred.winston@genetics.med.harvard.edu'),
    'lab' => 'Winston Lab',
    'name' => 'Fred Winston',
    'role' => 'user'
  },
  'h.yamano@mcri.ac.uk' => {
    'password' => sha1_base64('h.yamano@mcri.ac.uk'),
    'lab' => 'Yamano Lab',
    'name' => 'Hiro Yamano',
    'role' => 'user'
  },
  'test.user@pombase.org' => {
    'password' => sha1_base64('test.user@pombase.org'),
    'lab' => 'User Lab',
    'name' => 'Test User',
    'role' => 'user'
  },
  'Mary.Porter-Goff@umassmed.edu' => {
    'password' => sha1_base64('Mary.Porter-Goff@umassmed.edu'),
    'lab' => 'Rhind Lab',
    'name' => 'Mary Porter-Goff',
    'role' => 'user'
  },
  'some.testperson@pombase.org' => {
    'password' => sha1_base64('some.testperson@pombase.org'),
    'lab' => 'Testperson Lab',
    'name' => 'Some Testperson',
    'role' => 'user'
  },
  'val@sanger.ac.uk' => {
    'password' => sha1_base64('val@sanger.ac.uk'),
    'lab' => undef,
    'name' => 'Val Wood',
    'role' => 'admin'
  },
  'mah79@cam.ac.uk' => {
    'password' => sha1_base64('mah79@cam.ac.uk'),
    'lab' => undef,
    'name' => 'Midori Harris',
    'role' => 'admin'
  },
  'other.tester@pombase.org' => {
    'password' => sha1_base64('other.tester@pombase.org'),
    'lab' => 'Tester Lab',
    'name' => 'Other Tester',
    'role' => 'user'
  },
  'iwasaki@tsurumi.yokohama-cu.ac.jp' => {
    'password' => sha1_base64('iwasaki@tsurumi.yokohama-cu.ac.jp'),
    'lab' => '岩崎ひろし Lab',
    'name' => '岩崎ひろし',
    'role' => 'user'
  },
  'Nicholas.Willis@umassmed.edu' => {
    'password' => sha1_base64('Nicholas.Willis@umassmed.edu'),
    'lab' => 'Rhind Lab',
    'name' => 'Nicholas Willis',
    'role' => 'user'
  },
  'stuart.macneill@st-andrews.ac.uk' => {
    'password' => sha1_base64('stuart.macneill@st-andrews.ac.uk'),
    'lab' => 'Macneill Lab',
    'name' => 'Stuart Macneill',
    'role' => 'user'
  },
  'nick.rhind@umassmed.edu' => {
    'password' => sha1_base64('nick.rhind@umassmed.edu'),
    'lab' => 'Rhind Lab',
    'name' => 'Nick Rhind',
    'role' => 'user'
  },
  'Luis.Rokeach@umontreal.ca' => {
    'password' => sha1_base64('Luis.Rokeach@umontreal.ca'),
    'lab' => 'Rokeach Lab',
    'name' => 'Luis Rokeach',
    'role' => 'user'
  },
  'wahlswaynep@uams.edu' => {
    'password' => sha1_base64('wahlswaynep@uams.edu'),
    'lab' => 'Wahls Lab',
    'name' => 'Wayne Wahls',
    'role' => 'user'
  },
  'John.Burg@jhmi.edu' => {
    'password' => sha1_base64('John.Burg@jhmi.edu'),
    'lab' => 'Espenshade Lab',
    'name' => 'John Burg',
    'role' => 'user'
  },
  'a.nilsson@warwick.ac.uk' => {
    'password' => sha1_base64('a.nilsson@warwick.ac.uk'),
    'lab' => undef,
    'name' => 'Antonia Nilsson',
    'role' => 'admin',
  },
);

my %expected_labs = (

  'Wahls Lab' => {
    'head' => 'Wayne Wahls'
  },
  'Testperson Lab' => {
    'head' => 'Some Testperson'
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
  'Tester Lab' => {
    'head' => 'Other Tester'
  },
  'Yamano Lab' => {
    'head' => 'Hiro Yamano'
  },
  'Hardwick Lab' => {
    'head' => 'Kevin Hardwick'
  },
  '岩崎ひろし Lab', => {
    'head' => '岩崎ひろし',
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
     PMID:7958849 PMID:10467002 PMID:21801748";
my %expected_pubs = ();
@expected_pubs{@expected_pubs} = (ignore()) x @expected_pubs;

my $full_expected_track_data =
  {
    publications => \%expected_pubs,
    curation_sessions => {
      aaaa0007 => {
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
        %$small_expected_curation_session,
      },
      aaaa0006 => ignore(),
    },
    people => \%expected_people,
    labs => \%expected_labs,
  };


{
  my $curs_json = Canto::Curs::Serialise::json($config, $track_schema,
                                                'aaaa0007', { all_data => 1 });
  my $curs_ref = decode_json($curs_json);

  cmp_deeply($curs_ref, $full_expected_curation_session);
}

{
  my $curs_json = Canto::Curs::Serialise::json($config, $track_schema,
                                                'aaaa0007', { all_data => 0 });
  my $curs_ref = decode_json($curs_json);

  cmp_deeply($curs_ref, $small_expected_curation_session);
}

{
  my $curs_json = Canto::Curs::Serialise::json($config, $track_schema,
                                                'aaaa0007');
  my $curs_ref = decode_json($curs_json);

  cmp_deeply($curs_ref, $small_expected_curation_session);
}

sub check_track {
  my $options = shift;
  my ($count, $track_json) = Canto::Track::Serialise::json($config, $track_schema, $options);
  my $track_ref = decode_json($track_json);

  cmp_deeply($track_ref, $full_expected_track_data);

  my %curation_sessions = %{$track_ref->{curation_sessions}};
  is (keys %curation_sessions, 2);

  my $curation_session = $curation_sessions{aaaa0007};

  cmp_deeply($curation_session, { %$full_expected_curation_session });
}

check_track({ all_data => 1 });
