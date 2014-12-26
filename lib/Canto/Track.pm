package Canto::Track;

=head1 NAME

Canto::Track - Utilities for the tracking database

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;

with 'Canto::Role::MetadataAccess';

use File::Copy qw(copy);

use Canto::Config;
use Canto::Curs;
use Canto::CursDB;
use Canto::Util;
use Canto::Curs::State qw/:all/;

=head2 create_curs

 Usage   : my ($curs, $cursdb) =
             Canto::Track::create_curs($config, $track_schema, $pub_uniquename);
 Function: Create a curation session and return the Curs object and the CursDB
           object.
 Args    : $config - the Config object
           $track_schema - the TrackDB schema object
           $pub_uniquename - the uniquename (PMID) of a publication; the Pub
                             object will be created if it doesn't exist
 Return  :

=cut

sub create_curs
{
  my $config = shift;
  my $track_schema = shift;
  my $pub_uniquename = shift;

  my $pub = $track_schema->resultset('Pub')->find_or_create({ uniquename => $pub_uniquename });
  my $curs_key = Canto::Curs::make_curs_key();

  my $curs = $track_schema->create_with_type('Curs',
                                             {
                                               pub => $pub,
                                               curs_key => $curs_key,
                                             });

  my $curs_db = Canto::Track::create_curs_db($config, $curs);

  return ($curs, $curs_db);
}

=head2 create_curs_db

 Usage   : Canto::Track::create_curs_db($config, $curs_object);
 Function: Create a database for a curs, using the curs_key field of the object
           to create the database (file)name.
 Args    : $config - the Config object
           $curs - the Curs object
           $current_user - the current logged in user (or undef if no one is
                           logged in)
 Returns : ($curs_schema, $cursdb_file_name) - A CursDB object for the new db,
           and its file name - die()s on failure

=cut
sub create_curs_db
{
  my $config = shift;
  my $curs = shift;
  my $current_user = shift;

  if (!defined $curs) {
    croak "No Curs object passed";
  }

  my $uniquename = $curs->pub()->uniquename();
  my $curs_key = $curs->curs_key();

  my $db_file_name = Canto::Curs::make_long_db_file_name($config, $curs_key);

  if (-e $db_file_name) {
    die "Internal error: database for $curs_key already exists\n";
  }

  my $curs_db_template_file = $config->{curs_db_template_file};

  copy($curs_db_template_file, $db_file_name) or die "$!\n";

  my $connect_string = Canto::Curs::make_connect_string($config, $curs_key);
  my $curs_schema = Canto::CursDB->cached_connect($connect_string);

  my $track_db_pub = $curs->pub();
  my $curs_db_pub =
    $curs_schema->create_with_type('Pub',
                                   {
                                     uniquename => $uniquename,
                                     title => $track_db_pub->title(),
                                     authors => $track_db_pub->authors(),
                                     abstract => $track_db_pub->abstract(),
                                   });

  my $pub = $curs->pub();

  if (defined $current_user && $current_user->is_admin()) {
    __PACKAGE__->set_metadata($curs_schema, 'admin_session', 1);
  } else {
    $pub->community_curatable(1);
  }

  # the calling function will wrap this in a transaction if necessary
  __PACKAGE__->set_metadata($curs_schema, 'curation_pub_id', $curs_db_pub->pub_id);
  __PACKAGE__->set_metadata($curs_schema, 'curs_key', $curs->curs_key());
  __PACKAGE__->set_metadata($curs_schema,
                            Canto::Curs::State::SESSION_CREATED_TIMESTAMP_KEY,
                            Canto::Util::get_current_datetime());

  my $track_schema = $curs->result_source()->schema();

  my $curatable_name = 'Curatable';
  my $curatable_cvterm =
    $track_schema->resultset('Cvterm')->find({ name => $curatable_name });

  if (!defined $curatable_cvterm) {
    croak "Can't find Cvterm with name '$curatable_name'";
  }

  $pub->triage_status($curatable_cvterm);
  $pub->update();

  my $state = Canto::Curs::State->new(config => $config);
  $state->store_statuses($curs_schema);

  if (wantarray) {
    return ($curs_schema, $db_file_name);
  } else {
    return $curs_schema;
  }
}

=head2 create_curs_db_hook

 Usage   : Canto::Track::create_curs_db_hook($c, $curs_object);
 Function: Wrapper for create_curs_db() to be called from Edit::object()
 Args    : $c - the Catalyst object
           $curs - the Curs object

=cut
sub create_curs_db_hook
{
  my $c = shift;
  my $curs = shift;

  create_curs_db($c->config(), $curs, $c->user());
}

=head2

 Usage   : my $adaptor = Canto::Track::get_adaptor($config, 'gene');
 Function: return an initialised Lookup or Storage object of the given type
 Args    : $config - the Canto::Config object
           $adaptor_name - the adaptor type used to look up in the config
 Return  : a Adaptor object or undef if there isn't an adaptor of the
           given type configured

=cut
sub get_adaptor
{
  my ($config, $adaptor_name, $args) = @_;

  if (!defined $adaptor_name) {
    croak "no adaptor_name passed to get_adaptor()\n";
  }

  my $conf_name = "${adaptor_name}_adaptor";

  my $impl_class = $config->{implementation_classes}->{$conf_name};

  if (!defined $impl_class) {
    return undef;
  }

  my %args = ();

  if (defined $args) {
    %args = %$args;
  }

  eval "use $impl_class";
  die "failed to import $impl_class: $@" if $@;
  return $impl_class->new(config => $config, %args);
}

=head2 curs_iterator

 Usage   : my $iter = Canto::Track::curs_iterator($config, $track_schema);
           while (my ($curs, $cursdb) = $iter->()) {
             ...
           }
 Function: Return an iterator over the CursDB schema objects.  Each
           call to the iterator returns a (TrackDB::Curs, CursDB) pair, or
           () when there are no more.  The TrackDB is open for writing while
           iterating which may caused other writers to block.
 Args    : $config - the Canto::Config object
           $track_schema - the TrackDB schema

=cut
sub curs_iterator
{
  my $config = shift;
  my $track_schema = shift;

  my @curs_objects = $track_schema->resultset('Curs')->all();

  return sub {
    while (defined (my $curs = shift @curs_objects)) {
      my $curs_key = $curs->curs_key();
      my $curs_schema =
        Canto::Curs::get_schema_for_key($config, $curs_key,
                                        { cache_connection => 0 });
      if (defined $curs_schema) {
        return ($curs, $curs_schema);
      } else {
        next;
      }
    }
    return ();
  };
}

=head2 curs_map

 Usage   : my $proc = sub { ... };
           my @res = Canto::Track::curs_map($config, $track_schema, $proc);
 Function: call the $proc for each Curs, CursDB pair
 Args    : $config - the Canto::Config object
           $track_schema - the TrackDB schema
           $proc - a function the gets passed a Curs, CursDB and the
                   TrackDB schema
 Returns : a list of the results of the calls to $proc

=cut
sub curs_map
{
  my $config = shift;
  my $track_schema = shift;
  my $func = shift;

  my @ret = ();

  my @curs_objects = $track_schema->resultset('Curs')->all();

  while (defined (my $curs = shift @curs_objects)) {
    my $curs_key = $curs->curs_key();
    my $curs_schema =
      Canto::Curs::get_schema_for_key($config, $curs_key,
                                      { cache_connection => 0 });
    push @ret, $func->($curs, $curs_schema, $track_schema);
  }

  return @ret;
}

=head2

 Usage   : Canto::Track::delete_curs($config, $schema, $curs_key);
 Function: Delete the curs specified by the $curs_key from the track
           database and delete the cursdb itself
 Args    : $config - the Canto::Config object
           $schema - a TrackDB object
           $curs_key - the curs_key from the Curs object
 Returns : none

=cut
sub delete_curs
{
  my $config = shift;
  my $track_schema = shift;
  my $curs_key = shift;

  my $guard = $track_schema->txn_scope_guard;

  my $curs =
    $track_schema->resultset('Curs') ->find({ curs_key => $curs_key });

  $track_schema->resultset('Cursprop')
    ->search({ curs => $curs->curs_id() })->delete();

  $track_schema->resultset('CursCurator')
    ->search({ curs => $curs->curs_id() })->delete();

  $curs->delete();

  my $db_file_name = Canto::Curs::make_long_db_file_name($config, $curs_key);
  unlink $db_file_name or die "couldn't delete session $curs_key: $!";

  my @suffices = qw(journal wal shm);
  for my $suffix (@suffices) {
    unlink "$db_file_name-$suffix";
  }

  $guard->commit();
}

=head2

 Usage   : Canto::Track::tidy_curs($config, $curs_schema);
 Function: Tidy the curs databases by fixing problems caused by code
           changes.
 Args    : $config - the Canto::Config object
           $curs_db - the CursDB to clean
 Returns : none

=cut
sub tidy_curs
{
  my $config = shift;
  my $curs_db = shift;

  my $guard = $curs_db->txn_scope_guard;

  my $ann_rs = $curs_db->resultset('Annotation');

  while (defined (my $ann = $ann_rs->next())) {
    if ($ann->status() eq 'deleted') {
      warn "deleting annotation flagged as deleted\n";
      $ann->delete();
      next;
    }

    my $data = $ann->data();

    if (defined $data->{annotation_extension}) {
      if ($data->{annotation_extension} eq '') {
        delete $data->{annotation_extension};
        warn "deleting empty annotation\n";
        $ann->data($data);
        $ann->update();
      }
    }
  }

  $guard->commit();

}

=head2 validate_curs

 Usage   : Canto::Track::validate_curs($config, $track_schema, $curs);
 Function: Report inconsistencies in the given curation session.
           Checks that:
             - the PMID stored in the cursdb is the same as stored in
               trackdb
             - the curs_key stored in the metadata table matches the curs_key
               in the Track DB
 Args    : $config - the Canto::Config object
           $track_schema - the schema object for the trackdb
           $curs - the Curs object of interest
 Returns : a list of warning strings

=cut
sub validate_curs
{
  my $config = shift;
  my $track_schema = shift;
  my $curs = shift;

  my @res = ();

  my $trackdb_curs_key = $curs->curs_key();
  my $curs_schema =
    Canto::Curs::get_schema_for_key($config, $trackdb_curs_key);

  my $track_pub = $curs->pub();
  my $track_pub_uniquename = $track_pub->uniquename();

  my $curs_pub_id =
    $curs_schema->find_with_type('Metadata', 'key', 'curation_pub_id');
  my $curs_pub = $curs_schema->find_with_type('Pub', $curs_pub_id->value());
  my $curs_pub_uniquename = $curs_pub->uniquename();
  my $cursdb_curs_key =
    $curs_schema->find_with_type('Metadata', 'key', 'curs_key')->value();

  if ($track_pub_uniquename ne $curs_pub_uniquename) {
    push @res, qq{Pub uniquename in the trackdb ("$track_pub_uniquename") doesn't } .
               qq{match Pub uniquename in the cursdb ("$curs_pub_uniquename")};
  }

  if ($trackdb_curs_key ne $cursdb_curs_key) {
    push @res, qq{The curs_key stored in the trackdb ("$trackdb_curs_key") doesn't } .
               qq{match curs_key in the metadata table of the cursdb } .
               qq{("$cursdb_curs_key")};
  }

  return @res;
}

=head2 update_metadata

 Usage   : Canto::Track::update_metadata($config);
 Function: Set missing or out of date curs metadata.  Currently sets the
           session_created_timestamp
 Args    : $config - the Canto::Config object
 Return  : Nothing

=cut

sub update_metadata
{
  my $config = shift;

  my $state = Canto::Curs::State->new(config => $config);

  my $track_schema = Canto::TrackDB->new(config => $config);

  my $iter = Canto::Track::curs_iterator($config, $track_schema);

  while (my ($curs, $cursdb) = $iter->()) {
    $state->set_metadata($cursdb, Canto::Curs::State::SESSION_CREATED_TIMESTAMP_KEY(),
                         $curs->creation_date());
    $state->store_statuses($cursdb);
  }
}

1;
