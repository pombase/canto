package Canto::DB;

use strict;
use warnings;

use base 'DBIx::Class::Schema';
use feature 'state';

__PACKAGE__->load_classes;

for my $source (__PACKAGE__->sources()) {
  warn "$source\n";
  __PACKAGE__->source($source)->resultset_class('Canto::DB::ResultSet');
}

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::DB

You can also look for information at:

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

use Params::Validate qw(:all);
use Carp;

=head2 new

 Usage   : my $schema = Canto::DB->new(config => $c->config());
 Function: Return a new database connection (schema)
 Args    : $config - The configuration object

=cut
sub new
{
  my $self = shift;
  my %args = @_;

  my $config = $args{config};

  if (!defined $config) {
    croak "schema() needs a config hash as argument\n";
  }

  my $config_key = $self;

  my $con_info = $config->{$config_key}{connect_info};

  if (!defined $con_info) {
    $config_key =~ s/.*::(.*)DB/Model::${1}Model/;
    $con_info = $config->{$config_key}{connect_info};
    if (!defined $con_info) {
      croak "can't find configuration for $self (looked for: $config_key)\n";
    }
  }

  my $schema =
    $self->cached_connect($con_info->[0], $con_info->[1], $con_info->[2],
                          \%args);

  return $schema;
}

=head2 cached_connect

 Usage   : $schema = $class->cached_connect($connect_str, $user, $pass, $options)
 Function: Call $calls->connect() and cache the results if the connection is to
           an SQLite DB.
 Args    : $connect_str - a DBI connect strings eg. "dbi:SQLite:/tmp/db"
           $user        - the database user name (ignored by SQLite)
           $pass        - the database password (ignored by SQLite)
           $options     - valid options:
                            disable_foreign_keys - disable SQLite foreign keys
                                                   if true
                            cache_connection - cache the connection if 1
                                               (default: 1)

 Return  : the new schema

=cut

sub cached_connect
{
  my $class = shift;

  my ($connect_str, $user, $pass, $options) = @_;

  $options->{cache_connection} //= 1;

  state $cache = {};

  my $is_sqlite_db = $connect_str =~ /SQLite/;

  if ($options->{cache_connection} &&
      $is_sqlite_db && exists $cache->{$connect_str}) {
    return $cache->{$connect_str};
  }

  my $connect_options = {
    RaiseError => 1,
    AutoCommit => 1,
  };

  if ($is_sqlite_db) {
    $connect_options->{sqlite_use_immediate_transaction} = 1;
  }

  my $schema = $class->connect($connect_str, $user, $pass, $connect_options);

  my $dbh = $schema->storage()->dbh();

  if ($is_sqlite_db) {
    if (!$options->{disable_foreign_keys}) {
      $dbh->do("PRAGMA foreign_keys = ON");
    }
    $dbh->do("PRAGMA journal_mode = WAL;");
    $dbh->do("PRAGMA mmap_size=268435456;;");

    if ($options->{cache_connection}) {
      $cache->{$connect_str} = $schema;
    }
  }

  return $schema;
}

=head2 initialise

 Usage   : use base 'Canto::DB';   __PACKAGE__->initialise();
 Function: Initialise the ResultSet of DB sub-classes
 Note    : Must be called by sub-classes

=cut
sub initialise {
  my $self = shift;

  for my $source ($self->sources()) {
    $self->source($source)->resultset_class('Canto::ResultSet');
  }
}

=head2 find_with_type

 Usage   : my $obj = $schema->find_with_type('Organism', 'abbreviation', 'SCHPO');
       or: my $obj = $schema->find_with_type('Organism', { genus => 'Arabidopsis',
                                                           species => 'thaliana' } );
 Function: Return the object of the given type that has the given key field with
           given value or croak if no object is found
 Args    : $type - an unqualified class name like 'Person'
           $field_name - the field name to use when searching
           $value - the value to search for
       or: $type - an unqualified class name like 'Person'
           $arg - reference of the hash or a scalar to pass to find
                  eg. $schema->find({...});  or  $schema->find(5);

=cut
sub find_with_type
{
  my $self = shift;
  my ($type, $arg, $value) = validate_pos(@_, 1, 1, 0);

  $type = _make_short_classname($type);

  my $rs = $self->resultset($type);

  my $obj;

  if (!defined $value) {
    eval {
      $obj = $rs->find($arg);
    };
    if ($@) {
      use Carp "longmess";
      die "$@: ", longmess();
    }
    if (!defined $obj) {
      if (ref $arg) {
        my %args = %$arg;
        croak "error: could not find a '$type' with args: "
          . join "\n", map { "$_: $arg->{$_}" } keys %$arg;
      } else {
        croak "error: could not find a '$type' with arg: $arg";
      }
    }
  } else {
    my $field_name = $arg;
    $obj = $rs->find({ $field_name => $value });
    if (!defined $obj) {
      croak "error: could not find a '$type' with $field_name = '$value'\n";
    }
  }

  return $obj;
}

=head2 create_with_type

 Usage   : my $field_data = { first_name => 'Charles', last_name => 'Darwin',
                              organisation => $organisation };
           my $obj = $schema->create_with_type('Person', $field_data);
 Function: Create an object of the given type, initialising with the $field_data
 Args    : $type - an unqualified class name like 'Person'
           $field_data - a hashref containing all the fields to initialise in
           the new object
 Returns : a reference to the new object

=cut
sub create_with_type
{
  my $self = shift;
  my ($type, $field_data) = validate_pos(@_, 1, 1);

  $type = _make_short_classname($type);

  my $rs = $self->resultset($type);

 my $obj = undef;

  eval {
    $obj = $rs->create($field_data);
  };
  if ($@) {
    my $data_string = '{' . (join ', ', map {
      "'$_'" . ' => ' . "'" . ($field_data->{$_} // 'undef') . "'"
    } keys %$field_data) . '}';
    croak "error while creating $type: $@ with args: $data_string\n";
  }

  if (defined $obj) {
    return $obj;
  } else {
    croak "error: could not create a '$type'\n";
  }
}

=head2 find_or_create_with_type

 Usage   : my $field_data = { first_name => 'Charles', last_name => 'Darwin',
                              organisation => $organisation };
           my $obj = $schema->find_or_create_with_type('Person', $field_data);
 Function: Create an object of the given type, initialising with the
           $field_data, or return the existing object that matches the primary
           key
 Args    : $type - an unqualified class name like 'Person'
           $field_data - a hashref containing all the fields to initialise in
           the new object
 Returns : a reference to the new (or existing) object

=cut
sub find_or_create_with_type
{
  my $self = shift;
  my ($type, $field_data) = validate_pos(@_, 1, 1);

  $type = _make_short_classname($type);

  my $rs = $self->resultset($type);

  my $obj = undef;

  eval {
    $obj = $rs->find_or_create($field_data);
  };
  if ($@) {
    my $data_string = '{' . (join ', ', map {
      "'$_'" . ' => ' . "'" . $field_data->{$_} . "'"
    } keys %$field_data) . '}';
    croak "error while creating $type: $@ with args: $data_string\n";
  }

  if (defined $obj) {
    return $obj;
  } else {
    croak "error: could not create a '$type'\n";
  }
}

sub _make_short_classname
{
  my $table = shift;

  (my $class_name = $table) =~ s/_(\w)/uc $1/eg;

  return ucfirst $class_name;
}

=head2 class_name_of_table

 Usage   : my $class_name = Canto::DB->class_name_of_table($table_name);
 Function: Return the class name of a given table name
 Args    : $table_name - the table name
 Returns : the qualified class name, eg. Canto::DB::Person

=cut
sub class_name_of_table
{
  die if @_ != 2;
  my $self = shift;
  my $class_name = _make_short_classname(shift);
  my $db_name = ref($self) || $self;

  return $db_name . '::' . $class_name;
}

=head2 table_name_of_class

 Usage   : my $table_name = Canto::DB::table_name_of_class($class_name);
 Function: Return the table name of a given class name
 Args    : $class_name - the class name, can be unqualified or qualified
 Returns : the table name

=cut
sub table_name_of_class
{
  my $class_name = shift;

  if (!defined $class_name) {
    croak "undefined class_name passed to table_name_of_class()\n";
  }

  $class_name =~ s/(?:.*::)//;
  $class_name = join '_', map { lc } ($class_name =~ m/([A-Z][a-z]+)/g);
  return $class_name;
}

=head2 class_name_of_relationship

 Usage   : my $name = Canto::DB::class_name_of_relationship($object, $relname);
 Function: Return the class name of the object referred to by a relationship
 Args    : $object - an object
           $relname - the relationship name
 Returns : the class name

=cut
sub class_name_of_relationship
{
  my $object = shift;
  my $relname = shift;

  my %info = %{$object->relationship_info($relname)};
  return $info{class};
}

=head2 primary_key_field_name

 Usage   : my $field_name = Canto::DB::primary_key_field_name($object);
 Function: Return the name of the primary key field, which currently has to be
           the ID column.
           Multi-column primary keys aren't supported
 Args    : $object - the DBIX::Class object

=cut
sub primary_key_field_name
{
  my $object = shift;

  return ($object->primary_columns())[0];
}

=head2 id_of_object

 Usage   : my $id = Canto::DB::id_of_object($object);
 Function: Return the database id or primary key of the object, eg. for a
           sample, return the value in the sample_id column
 Args    : $object - an object

=cut
sub id_of_object
{
  my $object = shift;

  my $pk_field = primary_key_field_name($object);

  return $object->$pk_field();
}

=head2 display_name

 Usage   : my $display_name = Canto::DB::display_name($object);
             or
           my $display_name = Canto::DB::display_name($table_name);
             or
           my $display_name = Canto::DB::display_name($class_name);
 Function: return a description of a table that is suitable for display.
           eg. turn "sequencing_run" into "sequencing run"

=cut
sub display_name
{
  my $self = shift;
  my $arg = shift;

  if (ref $arg) {
    $arg = $arg->table();
  }

  if ($arg =~ /::/) {
    $arg = table_name_of_class($arg);
  }

  $arg =~ s/[_\-]/ /g;

  return "$arg";
}

=head2 column_type

 Usage   : my $column_type = Canto::DB::column_type($field_info, $table_name);
 Function: Return 'attribute' if a field is a plain attribute or 'collection'
           if it is a collection.

=cut
sub column_type {
  my $self = shift;
  my $field_info = shift;
  my $table_name = shift;

  my $class_name = $self->class_name_of_table($table_name);

  my $column_name = $field_info->{source};
  my $info_ref;
  if (defined $column_name) {
    $info_ref = $class_name->relationship_info($column_name);
  }

  if ($field_info->{is_collection} ||
        (defined $info_ref && defined $info_ref->{attrs}->{accessor}
           && $info_ref->{attrs}->{accessor} eq 'multi')) {
    return 'collection';
  } else {
    if (!defined $field_info->{source} || !ref $field_info->{source}) {
      return 'attribute';
    } else {
      return 'computed';
    }
  }
}

1;
