use strict;
use warnings;
use Test::More tests => 29;

use Test::Deep;

use Canto::Config;
use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();

my $config_yaml_1 = $test_util->root_dir() . '/t/data/50_config_1.yaml';
my $config_yaml_2 = $test_util->root_dir() . '/t/data/50_config_2.yaml';

my $config_single = Canto::Config->new([$config_yaml_1]);

is($config_single->{some_key}, 'some_value_1');

is(keys %{$config_single}, 19);

ok(!$config_single->{annotation_types}->{phenotype}->{needs_with_or_from});
ok($config_single->{annotation_types}->{cellular_component}->{needs_with_or_from});

my $lab_classinfo = $config_single->{class_info}->{track}->{lab};

# check that source defaults to name
is($lab_classinfo->{field_info_list}->[1]->{source},
   'lab_head');

# check that the field_infos hash is populated from the field_info_list
ok($lab_classinfo->{field_infos}->{people}->{is_collection});


# test loading two config files
my $config_two = Canto::Config->new([$config_yaml_1, $config_yaml_2]);

is($config_two->{some_key}, 'some_value_1');
is($config_two->{some_key_for_overriding}, 'overidden_value');
is(keys %{$config_two}, 19);


# test loading then merging
my $config_merge = Canto::Config->new([$config_yaml_1]);
$config_merge->merge_config([$config_yaml_2]);
$config_merge->setup();

is($config_merge->{some_key}, 'some_value_1');
is($config_merge->{some_key_for_overriding}, 'overidden_value');
is(keys %{$config_merge}, 19);

cmp_deeply($config_merge->{key_for_merging},
           {
             key1 => 'new_value1',
             key2 => 'value2',
             key3 => 'value3',
           });


my $lc_app_name = lc Canto::Config::get_application_name();
my $uc_app_name = uc $lc_app_name;


delete $ENV{"${uc_app_name}_CONFIG_LOCAL_SUFFIX"};

my $config_no_suffix = Canto::Config::get_config();

is($config_no_suffix->{name}, "Canto");
# only in <app_name>_local.yaml:
ok(not defined $config_no_suffix->{"Model::TrackModel"});
ok(keys %{$config_no_suffix->{class_info}} > 1);


$ENV{"${uc_app_name}_CONFIG_LOCAL_SUFFIX"} = 'local';

my $config_with_suffix = Canto::Config::get_config();

is($config_with_suffix->{name}, "Canto");
# only in <app_name>_local.yaml:
ok(defined $config_with_suffix->{"Model::TrackModel"});

ok(defined $config_with_suffix->model_connect_string('Track'));

is($config_with_suffix->{extra_css}, '/static/css/test_style.css');


# check extension configuration
ok ($config_with_suffix->{extension_configuration});


cmp_deeply(
  $config_with_suffix->{extension_configuration},
  [
    {
      'domain' => 'GO:0016023',
      'subset_rel' => ['is_a'],
      'allowed_relation' => 'has_substrate',
      'range' => [{ 'type' => 'Gene' }],
      'display_text' => 'kinase substrate',
      'help_text' => '',
      'cardinality' => ['0', '1'],
      'role' => 'user',
      'annotation_type_name' => 'cellular_component',
      'feature_type' => 'gene',
    },
    {
      'domain' => 'GO:0016023',
      'subset_rel' => ['is_a'],
      'allowed_relation' => 'happens_during',
      'range' => [
        {
          'type' => 'Ontology',
          'scope' => ['GO:0005215']
        }
      ],
      'display_text' => 'Something that happens during',
      'help_text' => '',
      'cardinality' => ['*'],
      'role' => 'user',
      'annotation_type_name' => 'cellular_component',
      'feature_type' => 'gene',
    },
    {
      'domain' => 'GO:0022857',
      'subset_rel' => ['is_a'],
      'allowed_relation' => 'localizes',
      'range' => [{'type' => 'Gene'}],
      'display_text' => 'localizes',
      'help_text' => '',
      'cardinality' => ['0', '1'],
      'role' => 'user',
      'annotation_type_name' => 'biological_process',
      'feature_type' => 'gene',
    },
    {
      'domain' => 'GO:0022857',
      'subset_rel' => ['is_a'],
      'allowed_relation' => 'occurs_at',
      'range' => [
        {
          'scope' => ['SO:0001799'],
          'type' => 'Ontology'
        }
      ],
      'display_text' => 'occurs at',
      'help_text' => '',
      'cardinality' => ['0', '1'],
      'role' => 'user',
      'annotation_type_name' => 'biological_process',
      'feature_type' => 'gene',
    },
    {
      'domain' => 'GO:0022857',
      'subset_rel' => ['is_a'],
      'allowed_relation' => 'modifies_residue',
      'range' => [
        {
          'type' => 'Text',
          'input_type' => 'text'
        }
      ],
      'display_text' => 'occurs at',
      'help_text' => '',
      'cardinality' => ['0', '1'],
      'role' => 'user',
      'annotation_type_name' => 'biological_process',
      'feature_type' => 'gene',
    },
    {
      'domain' => 'GO:0006810',
      'exclude_subset_ids' => ['is_a(GO:0055085)'],
      'subset_rel' => ['is_a'],
      'allowed_relation' => 'localizes',
      'range' => [{'type' => 'Gene'}],
      'display_text' => 'localizes',
      'help_text' => '',
      'cardinality' => ['0', '1'],
      'role' => 'user',
      'annotation_type_name' => 'biological_process',
      'feature_type' => 'gene',
    },
    {
      'domain' => 'GO:0034762',
      'subset_rel' => ['is_a'],
      'allowed_relation' => 'occurs_at',
      'range' => [{'type' => 'Gene'}],
      'display_text' => 'occurs at',
      'help_text' => '',
      'cardinality' => ['0', '1'],
      'role' => 'user',
      'annotation_type_name' => 'biological_process',
      'feature_type' => 'gene',
    },
    {
      'domain' => 'FYPO:0000002',
      'subset_rel' => ['is_a'],
      'allowed_relation' => 'assayed_using',
      'range' => [{'type' => 'Gene'}],
      'display_text' => 'assayed using',
      'help_text' => '',
      'cardinality' => ['0', '2'],
      'role' => 'user',
      'annotation_type_name' => 'phenotype',
      'feature_type' => 'genotype',
    },
    {
      'domain' => 'FYPO:0000002',
      'subset_rel' => ['is_a'],
      'allowed_relation' => 'has_penetrance',
      'range' => [
        {
          'type' => '%'
        },
        {
          'scope' => ['FYPO_EXT:1000000'],
          'type' => 'Ontology'
        },
      ],
      'display_text' => 'penetrance',
      'help_text' => '',
      'cardinality' => ['0', '1'],
      'role' => 'user',
      'annotation_type_name' => 'phenotype',
      'feature_type' => 'genotype',
    }
  ]
);

use JSON;

my $config_for_json = $config_with_suffix->for_json('allele_types');

my $description_required =
  $config_for_json->{'nucleotide substitution(s)'}->{description_required};
my $allele_name_required =
  $config_for_json->{'nucleotide substitution(s)'}->{allele_name_required};

ok ($description_required);
ok (!$allele_name_required);

ok ($description_required == JSON::true);
ok ($allele_name_required == JSON::false);

# species taxon ID lookup
is ($config_single->get_species_taxon_of_strain_taxon(1238467), 168172);
is ($config_single->get_species_taxon_of_strain_taxon(231718), 4565);
ok (!defined $config_single->get_species_taxon_of_strain_taxon(8765431));

