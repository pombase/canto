use strict;
use warnings;
use Test::More tests => 16;

use Canto::TestUtil;
use Canto::Curs::AlleleManager;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
$config->{implementation_classes}->{allele_adaptor} =
  'Canto::Chado::AlleleLookup';
$config->{implementation_classes}->{genotype_adaptor} =
  'Canto::Chado::GenotypeLookup';

my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 2);

my $curs_key = 'aaaa0007';

my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);


my $allele_manager = Canto::Curs::AlleleManager->new(config => $config,
                                                     curs_schema => $curs_schema);

my $SPBC1826_01c = $curs_schema->resultset('Gene')->find({
  primary_identifier => 'SPBC1826.01c',
});

is ($SPBC1826_01c->primary_identifier(), 'SPBC1826.01c');

my $new_allele = $allele_manager->allele_from_json(
  {
    type => 'partial deletion, amino acid',
    description => '100-200',
    name => 'SPBC1826.01c-c1',
    gene_id => $SPBC1826_01c->gene_id()
  },
  'aaaa0007');

is ($new_allele->primary_identifier(), 'SPBC1826.01c:aaaa0007-1');

my $existing_allele_identifier = 'SPAC27D7.13c:aaaa0007-4';
my $existing_allele = $allele_manager->allele_from_json(
  {
    primary_identifier => $existing_allele_identifier,
  });

is ($existing_allele->primary_identifier(), $existing_allele_identifier);


my $no_name_allele = $allele_manager->allele_from_json(
  {
    type => 'partial deletion, amino acid',
    name => '',
    description => '',
    expression => '',
    gene_id => $SPBC1826_01c->gene_id()
  },
  'aaaa0007');

ok (!defined $no_name_allele->name());
ok (!defined $no_name_allele->description());
ok (!defined $no_name_allele->expression());

# check that undef and '' and both stored and compared as undef
my $no_name_allele_check = $allele_manager->allele_from_json(
  {
    type => 'partial deletion, amino acid',
    gene_id => $SPBC1826_01c->gene_id()
  },
  'aaaa0007');

ok ($no_name_allele_check->allele_id() > 0);
is ($no_name_allele_check->allele_id(), $no_name_allele->allele_id());


$allele_manager->create_simple_allele('test_uniquename', 'unknown', 'some_name',
                                      'some_description', $SPBC1826_01c, []);

my $new_simple_allele = $curs_schema->resultset('Allele')
  ->find({ primary_identifier => 'test_uniquename' });

ok (defined $new_simple_allele);

is ($new_simple_allele->description(), 'some_description');
is ($new_simple_allele->gene()->primary_identifier(), 'SPBC1826.01c');


$allele_manager->create_simple_allele('test_aberration_uniquename', 'aberration',
                                      'some_aberration_name',
                                      'some_aberration_description', undef, []);

my $new_aberration = $curs_schema->resultset('Allele')
  ->find({ primary_identifier => 'test_aberration_uniquename' });

ok (defined $new_aberration);

is ($new_aberration->type(), 'aberration');
is ($new_aberration->description(), 'some_aberration_description');
ok (!defined($new_aberration->gene()));
