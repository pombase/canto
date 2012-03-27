use strict;
use warnings;
use Test::More tests => 18;

use Data::Compare;

use PomCur::TestUtil;
use PomCur::CursDB;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();

my $schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0007');

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

# test that a phenotype annotation exists and has the right type
my $phenotype_annotation_rs =
  $schema->resultset('Annotation')->search({ type => 'phenotype' });
is ($phenotype_annotation_rs->count(), 1);
is ($phenotype_annotation_rs->first()->data()->{term_ontid}, 'FYPO:0000013');

my $res_pub = $schema->find_with_type('Pub', { uniquename => 12345678 });

$res_pub->update();

my $new_res_pub = $schema->find_with_type('Pub', { uniquename => 12345678 });

my $spcc576_16c = $schema->find_with_type('Gene',
                                          { primary_identifier => 'SPCC576.16c' });
is ($spcc576_16c->direct_annotations()->count(), 0);
is ($spcc576_16c->indirect_annotations()->count(), 1);
is ($spcc576_16c->all_annotations()->count(), 1);

my $spcc63_05 = $schema->find_with_type('Gene',
                               { primary_identifier => 'SPCC63.05' });
is ($spcc63_05->direct_annotations()->count(), 3);
is ($spcc63_05->indirect_annotations()->count(), 0);
is ($spcc63_05->all_annotations()->count(), 3);

my $annotation_1_id = $spcc63_05->all_annotations()->first()->annotation_id();

my $spbc14f5_07 = $schema->find_with_type('Gene',
                                          { primary_identifier => 'SPAC27D7.13c' });
is ($spbc14f5_07->direct_annotations()->count(), 1);
is ($spbc14f5_07->indirect_annotations()->count(), 1);
is ($spbc14f5_07->all_annotations()->count(), 2);

my $annotation_2 = $spbc14f5_07->all_annotations()->first();
my $annotation_2_id = $annotation_2->annotation_id();


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
