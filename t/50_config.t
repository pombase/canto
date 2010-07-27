use strict;
use warnings;
use Test::More tests => 12;

use PomCur::Config;
use PomCur::TestUtil;

my $test_util = PomCur::TestUtil->new();

my $config_yaml_1 = $test_util->root_dir() . '/t/data/50_config_1.yaml';
my $config_yaml_2 = $test_util->root_dir() . '/t/data/50_config_2.yaml';

my $config_single = PomCur::Config->new($config_yaml_1);

is($config_single->{some_key}, 'some_value_1');
is(keys %{$config_single}, 4);

my $config_two = PomCur::Config->new($config_yaml_1, $config_yaml_2);

is($config_two->{some_key}, 'some_value_1');
is($config_two->{some_key_for_overriding}, 'overidden_value');
is(keys %{$config_two}, 4);

my $config_merge = PomCur::Config->new($config_yaml_1);
$config_merge->merge_config($config_yaml_2);

is($config_merge->{some_key}, 'some_value_1');
is($config_merge->{some_key_for_overriding}, 'overidden_value');
is(keys %{$config_merge}, 4);

my $lc_app_name = lc PomCur::Config::get_application_name();
my $uc_app_name = uc $lc_app_name;


delete $ENV{"${uc_app_name}_CONFIG_LOCAL_SUFFIX"};

my $config_no_suffix = PomCur::Config::get_config();

is($config_no_suffix->{name}, "PomCur");
# only in <app_name>_local.yaml:
ok(not defined $config_no_suffix->{"Model::TrackModel"});


$ENV{"${uc_app_name}_CONFIG_LOCAL_SUFFIX"} = 'local';

my $config_with_suffix = PomCur::Config::get_config();

is($config_with_suffix->{name}, "PomCur");
# only in <app_name>_local.yaml:
ok(defined $config_with_suffix->{"Model::TrackModel"});
