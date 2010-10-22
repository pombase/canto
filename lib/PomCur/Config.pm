package PomCur::Config;

=head1 NAME

PomCur::Config - Configuration information for PomCur Perl code

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Config

You can also look for information at:

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;

use Params::Validate qw(:all);
use YAML qw(LoadFile);
use Carp;

use v5.005;

use vars qw($VERSION);

$VERSION = '0.01';

=head2 new

 Usage   : my $config = PomCur::Config->new($file_name);
 Function: Create a new Config object from the file.

=cut
sub new
{
  my $class = shift;
  my @config_file_names = @_;

  my $self = LoadFile(shift @config_file_names);

  bless $self, $class;

  for my $config_file_name (@config_file_names) {
    # merge new config
    $self->merge_config($config_file_name);
  }

  $self->setup();

  return $self;
}

=head2 append_config

 Usage   : $config->append_config($config_file_name);
 Function: merge the another config file into a Config object

=cut
sub merge_config
{
  my $self = shift;
  my $file_name = shift;

  my %new_config = %{LoadFile($file_name)};
  while (my($key, $value) = each %new_config) {
    $self->{$key} = $value;
  }

  $self->setup();
}

=head2 setup

 Usage   : $config->setup();
 Function: perform initialisation for this object

=cut
sub setup
{
  my $self = shift;

  # make the field_infos available as a hash in the config
  for my $class_name (keys %{$self->{class_info}}) {
    my $class_info = $self->{class_info}->{$class_name};
    for my $field_info (@{$class_info->{field_info_list}}) {
      $field_info->{source} ||= $field_info->{name};
      my $name = $field_info->{name};
      if (!defined $name) {
        die "config loading failed: field_info with no name in $class_name\n";
      }
      $self->{class_info}->{$class_name}->{field_infos}->{$name} = $field_info;
    }
  }

  # make the reports available as a hash (by report name)
  if (defined $self->{report_list}) {
    for my $report (@{$self->{report_list}}) {
      my $name = $report->{name};
      $self->{reports}->{$name} = $report;
    }
  }

  # create an annotation_types hash from the annotation_type_list
  if (defined $self->{annotation_type_list}) {
    for my $annotation_type (@{$self->{annotation_type_list}}) {
      my $annotation_type_name = $annotation_type->{name};
      $self->{annotation_types}->{$annotation_type_name} = $annotation_type;
    }
  }
}

=head2

 Usage    : $app_name = PomCur::Config::get_application_name();
 Funcation: return the name of this application, based on the Config.pm package
            name (eg. "PomCur")

=cut
sub get_application_name
{
  (my $app_name = __PACKAGE__) =~ s/(.*?)::.*/$1/;

  return $app_name;
}

=head2 model_connect_string

 Usage   : my $connect_string = $config->model_connect_string('Track');
 Function: Return the connect string for the given model from the configuration
 Args    : $model_name - the model name to look up

=cut
sub model_connect_string
{
  my $self = shift;
  my $model_name = shift;

  if (!defined $model_name) {
    croak("no model_name passed to function\n");
  }

  return $self->{"Model::${model_name}Model"}->{connect_info}->[0];
}

=head2 get_config

 Usage   : $config = PomCur::Config::get_config();
 Function: Get a config object as Catalyst would, by looking for appname.yaml
           and merging the contents with appname_<suffix>.yaml, where <suffix>
           comes from the environment variable APPNAME_CONFIG_LOCAL_SUFFIX
=cut
sub get_config
{
  my $lc_app_name = lc get_application_name();
  my $uc_app_name = uc $lc_app_name;

  my $suffix = $ENV{"${uc_app_name}_CONFIG_LOCAL_SUFFIX"};

  my $file_name = "$lc_app_name.yaml";
  my $config = __PACKAGE__->new($file_name);

  if (defined $suffix) {
    my $local_file_name = "${lc_app_name}_$suffix.yaml";

    $config->merge_config($local_file_name);
  }

  return $config;
}

=head2 data_dir_path

 Usage   : my $path = $config->{$key};
 Function: return a value from the configuration hash relative to the
           data_directory
 Args    : $config_key - a key from the hash eg. "ontology_index_file"
 Returns : eg. "the_data_dir/" . $config{ontology_index_file}

=cut
sub data_dir_path
{
  my $self = shift;
  my $config_key = shift;

  my $file_name = $self->{$config_key};

  if (!defined $file_name) {
    croak "no configuration item with key '$config_key'";
  }

  return $self->{data_directory} . '/' . $file_name;
}

1;
