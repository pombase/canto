package PomCur::DBUtil;

=head1 NAME

PomCur::DBUtil - Utilities for database access

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::DBUtil

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

 Usage   : my $schema = PomCur::DBUtil::schema_for_file($config, $file_name,
                                                        $model_name);
 Function: Return a schema object for the given file
 Args    : $config - a PomCur::Config object
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
    schema_class => "PomCur::${model_name}DB",
    connect_info => ["dbi:SQLite:dbname=$file_name"],
  );

  my $model_class_name = "PomCur::${model_name}DB";

  eval " use $model_class_name; ";
  die $@ if $@;

  return $model_class_name->new(config => \%config_copy);
}

=head2 connect_string_file_name

 Usage   : my $file = PomCur::DBUtil::connect_string_file($connect_string);
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

=head2 set_db_version

 Usage   : PomCur::DBUtil::set_db_version($track_schema, $new_version);
 Function: Set the version entry in the metadata table to $new_version,
           which must be one more than the current version
 Return  : nothing or die if the $new_version isn't one more than the current
           version

=cut
sub set_db_version
{
  my $track_schema = shift;
  my $new_version = shift;

  my $schema_version_rs =
    $track_schema->resultset('Metadata')
                 ->search({ 'type.name' => 'schema_version' },
                          { join => 'type' });
  my $current_db_version = $schema_version_rs->first()->value();

  if ($current_db_version + 1 == $new_version) {
    my $schema_version_row = $schema_version_rs->first();
    $schema_version_row->value($new_version);
    $schema_version_row->update();
  } else {
    die "can't upgrade schema_version: $current_db_version\n";
  }
}

1;
