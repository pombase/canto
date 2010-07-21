#!/bin/sh
# make_classes.sh
# Created Mon Jun 21 2010 by Kim Rutherford Jun
# Script to create DBIx::Class classes for the schemas

TRACK_TEST_DB=/tmp/pomcur-track-test.db
CURS_TEST_DB=/tmp/pomcur-curs-test.db

rm -f $TRACK_TEST_DB $CURS_TEST_DB

sqlite3 $TRACK_TEST_DB < etc/track.sql
sqlite3 $CURS_TEST_DB < etc/curs.sql

./script/create_db_classes.pl PomCur::TrackDB dbi:SQLite:dbname=$TRACK_TEST_DB
./script/create_db_classes.pl PomCur::CursDB dbi:SQLite:dbname=$CURS_TEST_DB

./script/pomcur_create.pl model TrackModel DBIC::Schema PomCur::TrackDB
