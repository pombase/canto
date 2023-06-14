use strict;
use warnings;
use Test::More tests => 25;
use Test::Deep;

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
    gene_id => $SPBC1826_01c->gene_id(),
    notes => { test_key => 'test_note_value' },
  },
  'aaaa0007');

is ($new_allele->primary_identifier(), 'SPBC1826.01c:aaaa0007-1');

is ($new_allele->allele_notes()->count(), 1);

test_notes([
  {
    key => 'test_key',
    value => 'test_note_value',
  },
]);


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
                                      'some_description', undef, undef,
                                      $SPBC1826_01c, []);

my $new_simple_allele = $curs_schema->resultset('Allele')
  ->find({ primary_identifier => 'test_uniquename' });

ok (defined $new_simple_allele);

is ($new_simple_allele->description(), 'some_description');
is ($new_simple_allele->gene()->primary_identifier(), 'SPBC1826.01c');


$allele_manager->create_simple_allele('test_aberration_uniquename', 'aberration',
                                      'some_aberration_name',
                                      'some_aberration_description',  undef, undef,
                                      undef, []);

my $new_aberration = $curs_schema->resultset('Allele')
  ->find({ primary_identifier => 'test_aberration_uniquename' });

ok (defined $new_aberration);

is ($new_aberration->type(), 'aberration');
is ($new_aberration->description(), 'some_aberration_description');
ok (!defined($new_aberration->gene()));


# check that wildtype alleles are named automatically
my $no_name_wildtype_check = $allele_manager->allele_from_json(
  {
    type => 'wild type',
    gene_id => $SPBC1826_01c->gene_id()
  },
  'aaaa0007');

is ($no_name_wildtype_check->name(), 'mot1+');


## allele notes

sub test_notes
{
  my $expected = shift;

  my @db_notes = map {
    {
      key => $_->key(),
      value => $_->value(),
    };
  } $new_allele->allele_notes()->all();

  cmp_deeply(\@db_notes, $expected);
}

$allele_manager->set_note($new_allele->primary_identifier(),
                          'test_key', undef);

test_notes([]);

$allele_manager->set_note($new_allele->primary_identifier(),
                          'some_key', 'a value');
$allele_manager->set_note($new_allele->primary_identifier(),
                          'other_key', 'other value');

test_notes([
             {
               'key' => 'some_key',
               'value' => 'a value',
             },
             {
               'key' => 'other_key',
               'value' => 'other value',
             }
           ]);

$allele_manager->set_note($new_allele->primary_identifier(),
                          'some_key', 'changed value');
test_notes([
             {
               'key' => 'some_key',
               'value' => 'changed value',
             },
             {
               'key' => 'other_key',
               'value' => 'other value',
             }
           ]);

# delete
$allele_manager->set_note($new_allele->primary_identifier(),
                          'some_key', undef);
test_notes([
             {
               'key' => 'other_key',
               'value' => 'other value',
             }
           ]);

# delete again
$allele_manager->set_note($new_allele->primary_identifier(),
                          'some_key', undef);
test_notes([
             {
               'key' => 'other_key',
               'value' => 'other value',
             }
           ]);

$allele_manager->set_note($new_allele->primary_identifier(),
                          'other_key', undef);
test_notes([]);
