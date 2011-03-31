use strict;
use warnings;
use Test::More tests => 15;

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

my $curation_session = $curation_sessions[0];

my @genes = @{$curation_session->{genes}};

is (@genes, 1);

my $gene = $genes[0];

is ($gene->{primary_name}, "wtf22");

my @annotations = @{$gene->{annotations}};

is (@annotations, 1);

my $annotation = $annotations[0];

is_deeply ($annotation,
           {
             evidence_code => "IMP",
             creation_date => "2010-01-02",
             term_ontid => "GO:0055085",
             status => "new",
             type => "biological_process",
             publication => 'PMID:19756689'
           }
         );


my @publications = @{$curation_session->{publications}};
is (@publications, 1);
is ($publications[0]->{uniquename}, 'PMID:19756689');
like ($publications[0]->{abstract}, qr/SUMOylation/);

my @organisms = @{$curation_session->{organisms}};
is (@organisms, 1);
is ($organisms[0]->{full_name}, "Schizosaccharomyces pombe");

my @metadata = @{$curation_session->{metadata}};
my %metadata = map { (%$_) } @metadata;

is ($metadata{submitter_email}, 'henar@usal.es');
is ($metadata{submitter_name}, 'Henar Valdivieso');
is ($metadata{first_contact_email}, 'henar@usal.es');
is ($metadata{first_contact_name}, 'Henar Valdivieso');
is ($metadata{curs_key}, 'aaaa0006');
