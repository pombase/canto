use strict;
use warnings;
use Test::More tests => 2;

use PomCur::TestUtil;
use PomCur::WebUtil;
use PomCur::TrackDB;

my $lc_app_name = lc PomCur::Config::get_application_name();
my $uc_app_name = uc $lc_app_name;
$ENV{"${uc_app_name}_CONFIG_LOCAL_SUFFIX"} = 'local';

my $config = PomCur::Config::get_config();

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

my $col_conf_longname =
  $config->{class_info}->{person}->{field_infos}->{longname};

ok(defined $col_conf_longname);

my ($field_value, $field_type) =
  PomCur::WebUtil::get_field_value($mock_c, $person, $col_conf_longname);

is($field_value, 'Val Wood');
is($field_type, 'key_field');


my $col_conf_networkaddress =
  $config->{class_info}->{person}->{field_infos}->{networkaddress};

ok(defined $col_conf_networkaddress);

($field_value, $field_type) =
  PomCur::WebUtil::get_field_value($mock_c, $person, $col_conf_networkaddress);

is($field_value, $val_email);
is($field_type, 'key_field');
