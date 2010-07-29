use strict;
use warnings;
use Test::More tests => 6;

use PomCur::TestUtil;
use PomCur::WebUtil;
use PomCur::TrackDB;

my $test_util = PomCur::TestUtil->new();

my @config_file_names =
  ($test_util->root_dir() . '/pomcur_test.yaml',
   $test_util->root_dir() . '/t/data/50_config_1.yaml');

my $lc_app_name = lc PomCur::Config::get_application_name();
my $uc_app_name = uc $lc_app_name;

my $config = PomCur::Config->new(@config_file_names);

my $mock_c = { };

my $schema = PomCur::TrackDB->new($config);


# mock package
package PomCur;

sub schema
{
  return $schema;
}

sub config
{
  return $config;
}

bless $mock_c, "PomCur";


package main;

my $val_email = 'val@sanger.ac.uk';

my $person = $schema->find_with_type('Person',
                                     {
                                       networkaddress => $val_email
                                     });

my ($field_value, $field_type) =
  PomCur::WebUtil::get_field_value($mock_c, $person, 'longname');

is($field_value, 'Val Wood');
is($field_type, 'key_field');


($field_value, $field_type) =
  PomCur::WebUtil::get_field_value($mock_c, $person, 'Email address');

is($field_value, $val_email);
is($field_type, 'attribute');


my $lab = $schema->find_with_type('Lab',
                                  {
                                    name => 'Rhind Lab',
                                  });

($field_value, $field_type) =
  PomCur::WebUtil::get_field_value($mock_c, $lab, 'people');

ok(!defined $field_value);
is($field_type, 'collection');
