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

1;
