use strict;
use warnings;
use Test::More tests => 25;

use Test::Deep;

use Canto::Config;
use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();

my $config_yaml_1 = $test_util->root_dir() . '/t/data/50_config_1.yaml';
my $config_yaml_2 = $test_util->root_dir() . '/t/data/50_config_2.yaml';

my $config_single = Canto::Config->new($config_yaml_1);

is($config_single->{some_key}, 'some_value_1');

is(keys %{$config_single}, 9);

ok(!$config_single->{annotation_types}->{phenotype}->{needs_with_or_from});
ok($config_single->{annotation_types}->{cellular_component}->{needs_with_or_from});

my $lab_classinfo = $config_single->{class_info}->{track}->{lab};

# check that source defaults to name
is($lab_classinfo->{field_info_list}->[1]->{source},
   'lab_head');

# check that the field_infos hash is populated from the field_info_list
ok($lab_classinfo->{field_infos}->{people}->{is_collection});


# test loading two config files
my $config_two = Canto::Config->new($config_yaml_1, $config_yaml_2);

is($config_two->{some_key}, 'some_value_1');
is($config_two->{some_key_for_overriding}, 'overidden_value');
is(keys %{$config_two}, 9);


# test loading then merging
my $config_merge = Canto::Config->new($config_yaml_1);
$config_merge->merge_config($config_yaml_2);

is($config_merge->{some_key}, 'some_value_1');
is($config_merge->{some_key_for_overriding}, 'overidden_value');
is(keys %{$config_merge}, 9);

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

cmp_deeply($config_with_suffix->{extension_configuration},
          [
            {
              'display_text' => 'kinase substrate',
              'allowed_relation' => 'has_substrate',
              'subset_rel' => 'is_a',
              'cardinality' => [
                                 '0',
                                 '1'
                               ],
              'domain' => 'GO:0016023',
              'range' => 'GENE',
              'role' => 'user',
              'index' => 0,
            },
            {
              'display_text' => 'Something that happens during',
              'subset_rel' => 'is_a',
              'allowed_relation' => 'happens_during',
              'cardinality' => [
                                 '*'
                               ],
              'range' => 'GO:0005575',
              'domain' => 'GO:0016023',
              'role' => 'user',
              'index' => 1,
            },
            {
              'subset_rel' => 'is_a',
              'display_text' => 'localizes',
              'allowed_relation' => 'localizes',
              'cardinality' => [
                                 '0',
                                 '1'
                               ],
              'range' => 'GENE',
              'domain' => 'GO:0022857',
              'role' => 'user',
              'index' => 2,
            },
            {
              'display_text' => 'assayed using',
              'allowed_relation' => 'assayed_using',
              'subset_rel' => 'is_a',
              'cardinality' => [
                                 '0',
                                 '2'
                               ],
              'domain' => 'FYPO:0000002',
              'range' => 'GENE',
              'role' => 'user',
              'index' => 3,
            }
          ]);


use JSON;

my $config_for_json = $config_with_suffix->for_json('allele_types');

my $description_required =
  $config_for_json->{'mutation of a single nucleotide'}->{description_required};
my $allele_name_required =
  $config_for_json->{'mutation of a single nucleotide'}->{allele_name_required};

ok ($description_required);
ok (!$allele_name_required);

ok ($description_required == JSON::true);
ok ($allele_name_required == JSON::false);
