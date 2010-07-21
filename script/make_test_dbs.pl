#!/usr/bin/perl

my $empty_db_filename = "t/data/track_test_empty.sqlite3";
my $db_filename = "t/data/track_test.sqlite3";

unlink $empty_db_filename;
unlink $db_filename;

system "sqlite3 $empty_db_filename < etc/track.sql";
system "sqlite3 $db_filename < etc/track.sql";
