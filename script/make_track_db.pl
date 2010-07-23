#!/usr/bin/perl

my $empty_db_filename = "db_templates/track_db_template.sqlite3";
unlink $empty_db_filename;
system "sqlite3 $empty_db_filename < etc/track.sql";
