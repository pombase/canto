use strict;
use warnings;
use Test::More tests => 25;
use Test::Deep;

use Canto::TestUtil;
use Canto::CursDB;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();

my $schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

ok($schema);

# test inflating and deflating of data
$schema->txn_do(
  sub {
    $schema->create_with_type('Pub', { uniquename => 12345678,
                                       title => "a title",
                                       abstract => "abstract text",
                                       authors => "author list",
                                     });
  });


# get genotype annotations
my $genotype = $schema->resultset('Genotype')->find({ identifier => 'aaaa0007-genotype-test-1' });
my @genotype_annotations = $genotype->annotations();

is ($genotype->display_name($config), "SPCC63.05delta ssm4KE");

is (@genotype_annotations, 1);

my $genotype_0 = ($genotype_annotations[0]->genotypes())[0];

my @alleles_0 =
  sort {
    $a->long_identifier($config)
      cmp
    $b->long_identifier($config)
  } $genotype_0->alleles();

cmp_deeply(
  [
    {
      'name' => 'SPCC63.05delta',
      'primary_identifier' => 'SPCC63.05:aaaa0007-1',
      'description' => 'deletion',
      'type' => 'deletion',
      'expression' => undef,
      'long_identifier' => 'SPCC63.05delta',
      'display_name' => 'SPCC63.05delta',
    },
    {
      'name' => 'ssm4delta',
      'primary_identifier' => 'SPAC27D7.13c:aaaa0007-1',
      'description' => 'deletion',
      'type' => 'deletion',
      'expression' => undef,
      'long_identifier' => 'ssm4delta',
      'display_name' => 'ssm4delta',
    }
   ],
  [map {
    {
      primary_identifier => $_->primary_identifier(),
      type => $_->type(),
      description => $_->description(),
      expression => $_->expression(),
      name => $_->name(),
      long_identifier => $_->long_identifier($config),
      display_name => $_->display_name($config)
    };
  } @alleles_0]);

# test that a phenotype annotation exists and has the right type
my $phenotype_annotation_rs =
  $schema->resultset('Annotation')->search({ type => 'phenotype' });
is ($phenotype_annotation_rs->count(), 2);
is ($phenotype_annotation_rs->first()->data()->{term_ontid}, 'FYPO:0000013');

my $res_pub = $schema->find_with_type('Pub', { uniquename => 12345678 });

$res_pub->update();

my $new_res_pub = $schema->find_with_type('Pub', { uniquename => 12345678 });

my $spbc1826_01c = $schema->find_with_type('Gene',
                                          { primary_identifier => 'SPBC1826.01c' });
is ($spbc1826_01c->direct_annotations()->count(), 0);
is ($spbc1826_01c->indirect_annotations()->count(), 1);
is ($spbc1826_01c->all_annotations(include_with => 1)->count(), 1);

my $spcc63_05 = $schema->find_with_type('Gene',
                               { primary_identifier => 'SPCC63.05' });
is ($spcc63_05->direct_annotations()->count(), 1);
is ($spcc63_05->indirect_annotations()->count(), 0);
is ($spcc63_05->all_annotations(include_with => 1)->count(), 1);

my $annotation_1_id = $spcc63_05->all_annotations(include_with => 1)->first()->annotation_id();

my $spbc14f5_07 = $schema->find_with_type('Gene',
                                          { primary_identifier => 'SPAC27D7.13c' });
is ($spbc14f5_07->direct_annotations()->count(), 1);
is ($spbc14f5_07->indirect_annotations()->count(), 0);
is ($spbc14f5_07->all_annotations(include_with => 1)->count(), 1);

my $annotation_2 = $spbc14f5_07->all_annotations(include_with => 1)->first();
my $annotation_2_id = $annotation_2->annotation_id();

my $genotype_1 = $schema->find_with_type('Genotype', { identifier => 'aaaa0007-genotype-test-2' });
ok (defined $genotype_1);

is ($genotype_1->annotations()->count(), 1);


# delete gene and make sure the annotation goes too
ok (defined ($schema->find_with_type('Annotation', $annotation_1_id)));
ok (defined ($schema->find_with_type('GeneAnnotation',
                          { gene => $spcc63_05->gene_id(),
                            annotation => $annotation_1_id })));

$spcc63_05->delete();
ok (!defined ($schema->resultset('Annotation')->find($annotation_1_id)));
ok (!defined ($schema->resultset('GeneAnnotation')
              ->find({ gene => $spcc63_05->gene_id(),
                       annotation => $annotation_1_id })));


# delete annotation and make sure the GeneAnnotation row goes too
my $gene_annotation =
  $schema->find_with_type('GeneAnnotation',
                          { gene => $spbc14f5_07->gene_id(),
                            annotation => $annotation_2_id });
ok (defined $gene_annotation);

$annotation_2->delete();

my $gene_annotation_again =
  $schema->resultset('GeneAnnotation')
    ->find({ gene => $spbc14f5_07->gene_id(),
             annotation => $annotation_2_id });
ok (!defined $gene_annotation_again);


# make sure we can delete all genes

my $genes_rs = $schema->resultset('Gene');
is ($genes_rs->count, 3);

map { $_->delete(); } $genes_rs->all();
is ($genes_rs->count(), 0);
