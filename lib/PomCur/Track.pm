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
 Returns : ($curs_schema, $cursdb_file_name) - A CursDB object for the new db,
           and its file name - die()s on failure

=cut
sub create_curs_db
{
  my $config = shift;
  my $curs = shift;

  my $uniquename = $curs->pub()->uniquename();
  my $curs_key = $curs->curs_key();

  my $exists_flag = 1;

  my $db_file_name = PomCur::Curs::make_long_db_file_name($config, $curs_key);

  if (-e $db_file_name) {
    die "Internal error: database already exists\n";
  }

  my $curs_db_template_file = $config->{curs_db_template_file};

  copy($curs_db_template_file, $db_file_name) or die "$!\n";

  my $connect_string = PomCur::Curs::make_connect_string($config, $curs_key);
  my $curs_schema = PomCur::CursDB->connect($connect_string);

  my $first_contact_email = $curs->curator()->networkaddress();
  my $first_contact_name = $curs->curator()->name();

  my $track_db_pub = $curs->pub();
  my $curs_db_pub =
    $curs_schema->create_with_type('Pub',
                                   {
                                     uniquename => $uniquename,
                                     title => $track_db_pub->title(),
                                     abstract => $track_db_pub->abstract(),
                                   });

  # the calling function will wrap this in a transaction if necessary
  set_metadata($curs_schema, 'first_contact_email', $first_contact_email);
  set_metadata($curs_schema, 'first_contact_name', $first_contact_name);
  set_metadata($curs_schema, 'curation_pub_id', $curs_db_pub->pub_id);
  set_metadata($curs_schema, 'curs_key', $curs->curs_key());

  if (wantarray) {
    return ($curs_schema, $db_file_name);
  } else {
    return $curs_schema;
  }
}

=head2 create_curs_db_hook

 Usage   : PomCur::Track::create_curs_db_hook($config, $curs_object);
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
 Function: return an initialised Adaptor object of the given type
 Args    : $config - the PomCur::Config object
           $adaptor_name - the adaptor type used to look up in the config
 Return  : a Adaptor object

=cut
sub get_adaptor
{
  my ($config, $adaptor_name) = @_;

  if (!defined $adaptor_name) {
    croak "no adaptor_name passed to get_adaptor()\n";
  }

  my $conf_name = "${adaptor_name}_adaptor";

  my $impl_class = $config->{implementation_classes}->{$conf_name};

  if (!defined $impl_class) {
    croak "can't find implementation class for $conf_name";
  }

  eval "use $impl_class";
  die "failed to import $impl_class: $@" if $@;
  return $impl_class->new(config => $config);
}

=head2 cursdb_file_name

 Usage   : my $iter = PomCur::Track::cursdb_iterator($config, $track_schema);
           while (my $cursdb = $iter->()) {
             ...
           }
 Function: Return an iterator over the CursDB schema
 Args    : $config - the PomCur::Config object
           $track_schema - the TrackDB schema
 Returns :

=cut
sub cursdb_iterator
{
  my $config = shift;
  my $track_schema = shift;

  my $curs_rs = $track_schema->resultset('Curs');

  my @curs_keys = ();

  while (defined (my $curs = $curs_rs->next())) {
    push @curs_keys, $curs->curs_key();
  }

  return sub {
    if (@curs_keys) {
      while (defined (my $curs_key = shift @curs_keys)) {
        my $curs_schema = PomCur::Curs::get_schema_for_key($config, $curs_key);

        if (defined $curs_schema) {
          return $curs_schema;
        } else {
          next;
        }
      }
    } else {
      return undef;
    }
  };
}

1;
