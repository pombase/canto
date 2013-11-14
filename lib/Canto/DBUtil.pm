package Canto::DBUtil;

=head1 NAME

Canto::DBUtil - Utilities for database access

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::DBUtil

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

=head2

 Usage   : my $schema = Canto::DBUtil::schema_for_file($config, $file_name,
                                                        $model_name);
 Function: Return a schema object for the given file
 Args    : $config - a Canto::Config object
           $file_name - the file name of the database
           $model_name - the name of the model to make the schema for,
                         eg. "Track" or "Curs"
 Return  : the schema

=cut
sub schema_for_file
{
  my $config = shift;
  my $file_name = shift;
  my $model_name = shift;

  my %config_copy = %$config;

  %{$config_copy{"Model::${model_name}Model"}} = (
    schema_class => "Canto::${model_name}DB",
    connect_info => ["dbi:SQLite:dbname=$file_name"],
  );

  my $model_class_name = "Canto::${model_name}DB";

  eval " use $model_class_name; ";
  die $@ if $@;

  return $model_class_name->new(config => \%config_copy);
}

=head2 connect_string_of_schema

 Usage   : my $connect_string = Canto::DBUtil::connect_string_of_schema($schema);
 Function: Return the connect string that was passed to connect()
 Args    : $schema - the DBIx::Class::Schema object

=cut

sub connect_string_of_schema
{
  my $schema = shift;

  return ($schema->storage()->connect_info())[0];
}

=head2 connect_string_file_name

 Usage   : my $file = Canto::DBUtil::connect_string_file($connect_string);
 Function: Return the db file name from an sqlite connect string
 Args    : $connect_string
 Return  : the file name

=cut
sub connect_string_file_name
{
  my $connect_string = shift;

  (my $db_file_name = $connect_string) =~ s/dbi:SQLite:dbname=(.*)/$1/;

  return $db_file_name;
}

sub _schema_version_rs
{
  my $track_schema = shift;

  return $track_schema->resultset('Metadata')
    ->search({ 'type.name' => 'schema_version' },
             { join => 'type' });

}

=head2 set_schema_version

 Usage   : Canto::DBUtil::set_schema_version($track_schema, $new_version);
 Function: Set the version entry in the metadata table to $new_version,
           which must be one more than the current version
 Return  : nothing or die if the $new_version isn't one more than the current
           version

=cut
sub set_schema_version
{
  my $track_schema = shift;
  my $new_version = shift;

  my $schema_version_rs = _schema_version_rs($track_schema);
  my $current_db_version = $schema_version_rs->first()->value();

  if ($current_db_version + 1 == $new_version) {
    my $schema_version_row = $schema_version_rs->first();
    $schema_version_row->value($new_version);
    $schema_version_row->update();
  } else {
    die "can't upgrade schema_version from $current_db_version to $new_version\n";
  }
}

=head2 get_schema_version

 Usage   : my $version = Canto::DBUtil::get_schema_version($track_schema)
 Function: Return the schema_version from the metadata table
 Args    : $track_schema - a TrackDB object
 Return  : the version

=cut

sub get_schema_version
{
  my $track_schema = shift;

  my $schema_version_rs = _schema_version_rs($track_schema);
  return $schema_version_rs->first()->value();
}

=head2 check_schema_version

 Usage   : Canto::DBUtil::check_schema_version($config, $track_schema);
 Function: Check that the code matches the database schema version.
 Args    : $config - a Canto::Config object
           $track_schema - a TrackDB object
 Return  : nothing, dies if there is a mismatch

=cut

sub check_schema_version
{
  my $config = shift;
  my $schema = shift;

  my $db_schema_version = get_schema_version($schema);
  my $config_schema_version = $config->{schema_version};

  if ($config_schema_version != $db_schema_version) {
    die "Initialisation failed; the database schema version " .
      "($db_schema_version) doesn't match the version expected by the code " .
      "($config_schema_version)\n";
  }
}

1;
