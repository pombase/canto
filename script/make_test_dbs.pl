#!/usr/bin/perl

my $empty_db_filename = "t/data/track_test_empty.sqlite3";
my $db_filename = "t/data/track_test.sqlite3";

unlink $empty_db_filename;
unlink $db_filename;

system "sqlite3 $empty_db_filename < etc/track.sql";
system "sqlite3 $db_filename < etc/track.sql";

use PomCur::TrackDB;
use PomCur::Config;

my $config = PomCur::Config->new("t/test_properties.yaml");
my $trackdb_conf = $config->{"Model::TrackModel"};
push @{$trackdb_conf->{connect_info}}, "dbi:SQLite:dbname=$db_filename";

my $schema = PomCur::TrackDB->new($config);

$schema->create_with_type('Person', { networkaddress => 'x@x',
                                      longname => 'xx',
                                      shortname => 'x',
                                      role => 'user',
                                      password => 'x' });

