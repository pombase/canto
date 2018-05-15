use strict;
use warnings;
use Test::More tests => 18;

use LWP::Protocol::PSGI;
use YAML qw(Load Dump);

use Canto::TestUtil;
use Package::Alias
  OntologyAnnotationLookup => 'Canto::UniProt::OntologyAnnotationLookup';

my $test_util = Canto::TestUtil->new();

$test_util->init_test();
my $config = $test_util->config();


my $quickgo_gaf_filename = $config->{test_config}->{test_quickgo_gaf};
my $quickgo_gaf_fullname =
  $test_util->test_data_dir_full_path($quickgo_gaf_filename);

my $app = sub {
  local $/ = undef;
  my $env = shift;
  my $quickgo_gaf_fh = new IO::File $quickgo_gaf_fullname, "r";
  return [
    200,
    ['Content-Type' => 'text/plain'],
    $quickgo_gaf_fh,
  ];
};

LWP::Protocol::PSGI->register($app);

sub _check_res
{
  my $res = shift;

  my @res = @$res;

  is ($res[0]->{ontology_term}->{ontid}, 'GO:0022857');
  is ($res[0]->{ontology_term}->{term_name}, 'transmembrane transporter activity');
  is ($res[0]->{ontology_term}->{ontology_name}, 'molecular_function');
  is ($res[1]->{gene}->{identifier}, 'O74473');
  is ($res[1]->{gene}->{name}, 'CDC11_SCHPO');
  is ($res[1]->{gene}->{organism_taxonid}, '284812');
  is ($res[1]->{publication}, 'PMID:11676915');
}


my $lookup =
  Canto::UniProt::OntologyAnnotationLookup->new(config => $config);

my $res = $lookup->lookup({ pub_uniquename => 'PMID:11676915',
                            gene_identifier => 'O74473',
                            ontology_name => 'molecular_function' });

ok(defined $res);
ok(ref $res);

_check_res($res);


# try again to make sure the caching is working
my $res2 = $lookup->lookup({ pub_uniquename => 'PMID:11676915',
                             gene_identifier => 'O74473',
                             ontology_name => 'molecular_function' });

ok(defined $res2);
ok(ref $res2);

_check_res($res2);
