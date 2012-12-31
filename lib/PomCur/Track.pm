package PomCur::Track;

=head1 NAME

PomCur::Track - Utilities for the tracking database

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;

with 'PomCur::Role::MetadataAccess';

use File::Copy qw(copy);

use PomCur::Config;
use PomCur::Curs;
use PomCur::CursDB;

=head2 create_curs

 Usage   : PomCur::Track::create_curs_db($config, $curs_object);
 Function: Create a database for a curs, using the curs_key field of the object
           to create the database (file)name.
 Args    : $config - the Config object
           $curs - the Curs object
           $admin_session - if true the assigned_curator is assumed to be an
                            admin user so the "Curator details" page is skipped
 Returns : ($curs_schema, $cursdb_file_name) - A CursDB object for the new db,
           and its file name - die()s on failure

=cut
sub create_curs_db
{
  my $config = shift;
  my $curs = shift;
  my $admin_session = shift // 0;

  my $uniquename = $curs->pub()->uniquename();
  my $curs_key = $curs->curs_key();

  my $db_file_name = PomCur::Curs::make_long_db_file_name($config, $curs_key);

  if (-e $db_file_name) {
    die "Internal error: database for $curs_key already exists\n";
  }

  my $curs_db_template_file = $config->{curs_db_template_file};

  copy($curs_db_template_file, $db_file_name) or die "$!\n";

  my $connect_string = PomCur::Curs::make_connect_string($config, $curs_key);
  my $curs_schema = PomCur::CursDB->connect($connect_string);

  my $first_contact_email;
  my $first_contact_name;

  my $track_db_pub = $curs->pub();
  my $curs_db_pub =
    $curs_schema->create_with_type('Pub',
                                   {
                                     uniquename => $uniquename,
                                     title => $track_db_pub->title(),
                                     authors => $track_db_pub->authors(),
                                     abstract => $track_db_pub->abstract(),
                                   });

  if (defined $curs->assigned_curator()) {
    my $first_contact_name = $curs->assigned_curator()->name();
    my $first_contact_email = $curs->assigned_curator()->email_address();
    __PACKAGE__->set_metadata($curs_schema, 'first_contact_email', $first_contact_email);
    __PACKAGE__->set_metadata($curs_schema, 'first_contact_name', $first_contact_name);

    if ($admin_session) {
      __PACKAGE__->set_metadata($curs_schema, 'submitter_email', $first_contact_email);
      __PACKAGE__->set_metadata($curs_schema, 'submitter_name', $first_contact_name);
      __PACKAGE__->set_metadata($curs_schema, 'admin_session', 1);
    }
  }

  # the calling function will wrap this in a transaction if necessary
  __PACKAGE__->set_metadata($curs_schema, 'curation_pub_id', $curs_db_pub->pub_id);
  __PACKAGE__->set_metadata($curs_schema, 'curs_key', $curs->curs_key());

  if (wantarray) {
    return ($curs_schema, $db_file_name);
  } else {
    return $curs_schema;
  }
}

=head2 create_curs_db_hook

 Usage   : PomCur::Track::create_curs_db_hook($c, $curs_object);
 Function: Wrapper for create_curs_db() to be called from Edit::object()
 Args    : $c - the Catalyst object
           $curs - the Curs object

=cut
sub create_curs_db_hook
{
  my $c = shift;
  my $curs = shift;

  create_curs_db($c->config(), $curs);
}

=head2

 Usage   : my $adaptor = PomCur::Track::get_adaptor($config, 'gene');
 Function: return an initialised Lookup or Storage object of the given type
 Args    : $config - the PomCur::Config object
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

 Usage   : my $iter = PomCur::Track::curs_iterator($config, $track_schema);
           while (my ($curs, $cursdb) = $iter->()) {
             ...
           }
 Function: Return an iterator over the CursDB schema objects.  Each
           call to the iterator returns a (TrackDB::Curs, CursDB) pair, or
           () when there are no more.
 Args    : $config - the PomCur::Config object
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
        PomCur::Curs::get_schema_for_key($config, $curs_key);
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
           my @res = PomCur::Track::curs_map($config, $track_schema, $proc);
 Function: use curs_iterator() to call the $proc for each Curs, CursDB pair
 Args    : $config - the PomCur::Config object
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

  my $iter = curs_iterator($config, $track_schema);
  while (my ($curs, $curs_schema) = $iter->()) {
    push @ret, $func->($curs, $curs_schema, $track_schema);
  }

  return @ret;
}

=head2

 Usage   : PomCur::Track::delete_curs($config, $schema, $curs_key);
 Function: Delete the curs specified by the $curs_key from the track
           database and delete the cursdb itself
 Args    : $config - the PomCur::Config object
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

  my $db_file_name = PomCur::Curs::make_long_db_file_name($config, $curs_key);
  unlink $db_file_name;

  $guard->commit();
}

=head2

 Usage   : PomCur::Track::tidy_curs($config, $curs_schema);
 Function: Tidy the curs databases by fixing problems caused by code
           changes.
 Args    : $config - the PomCur::Config object
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

 Usage   : PomCur::Track::validate_curs($config, $track_schema, $curs);
 Function: Report inconsistencies in the given curation session.
           Checks that:
             - the PMID stored in the cursdb is the same as stored in
               trackdb
             - the curs_key stored in the metadata table matches the curs_key
               in the Track DB
 Args    : $config - the PomCur::Config object
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
    PomCur::Curs::get_schema_for_key($config, $trackdb_curs_key);

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
1;
