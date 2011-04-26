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
use Clone qw(clone);
use Carp;

use v5.005;

use vars qw($VERSION);

$VERSION = '0.01';

my $app_config_file = "pomcur.yaml";
my $test_config_file = "t/test_config.yaml";

=head2 new

 Usage   : my $config = PomCur::Config->new($file_name, [$file_name_2, ...]);
 Function: Create a new Config object from the given files.  If no files are
           given read from the default application configuration file.

=cut
sub new
{
  my $class = shift;
  my @config_file_names = @_;

  if (@config_file_names == 0) {
    push @config_file_names, $app_config_file;
  }

  my $self = LoadFile(shift @config_file_names);

  bless $self, $class;

  for my $config_file_name (@config_file_names) {
    # merge new config
    $self->merge_config($config_file_name);
  }

  $self->setup();

  return $self;
}

=head2 new_test_config

 Usage   : my $config = PomCur::Config->new_test_config();
 Function: Create a Config object including the test settings
 Args    : none

=cut
sub new_test_config
{
  my $self = shift;

  return $self->new($app_config_file, $test_config_file);
}

=head2 merge_config

 Usage   : $config->merge_config($config_file_name, [...]);
 Function: merge the given config files into a Config object

=cut
sub merge_config
{
  my $self = shift;
  my @file_names = @_;

  for my $file_name (@file_names) {
    my %new_config = %{LoadFile($file_name)};
    while (my($key, $value) = each %new_config) {
      $self->{$key} = $value;
    }
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

  # make the field_infos available as a hash in the config and make
  # the config inheritable using "extends"
  for my $model (keys %{$self->{class_info}}) {
    my $model_conf = $self->{class_info}->{$model};
    for my $class_name (keys %{$model_conf}) {
      my $class_info = $model_conf->{$class_name};

      $class_info->{name} = $class_name;
      my $display_name =
        $class_info->{class_display_name};
      if (!defined $display_name) {
        $display_name = $class_info->{name};
        $display_name =~ s/_/ /g;
      }

      $class_info->{display_name} = $display_name;

      my $parent_name = $class_info->{extends};

      if (!defined $parent_name) {
        $class_info->{source} //= $class_name;
        $class_info->{search_fields} //= [ $class_info->{display_field} ];
      }
    }

    for my $class_name (keys %{$model_conf}) {
      my $class_info = $model_conf->{$class_name};

      my $parent_name = $class_info->{extends};

      if (defined $parent_name) {
        my $parent_info = $model_conf->{$parent_name};

        if (!defined $parent_info) {
          die "parent configuration '$parent_name' not found in " .
            "configuration for: $class_name";
        }

        while (my ($key, $value) = each %$parent_info) {
          if (!exists $class_info->{$key}) {
            $class_info->{$key} = clone $parent_info->{$key};
          }
        }

#        delete $class_info->{extends};

        # keys starting with "+" should be merged into the parent config
        while (my ($key, $value) = each %$class_info) {
          if ($key =~ /^\+(.*)/) {
            my $real_key = $1;

            if (ref $class_info->{$real_key} eq 'HASH') {
              while (my ($sub_key, $sub_value) = each %{$class_info->{$key}}) {
                if (exists $class_info->{$real_key}->{$sub_key}) {
                  die "key '$sub_key' in child configuration '$class_name' " .
                  "would overwrite configuration from parent";
                } else {
                  $class_info->{$real_key}->{$sub_key} =
                    $class_info->{$key}->{$sub_key};
                }
              }
            } else {
              if (ref $class_info->{$real_key} eq 'ARRAY') {
                push @{$class_info->{$real_key}}, @{$class_info->{$key}};
              }
            }

            delete $class_info->{$key};
          }
        }
      }

      for my $field_info (@{$class_info->{field_info_list}}) {
        $field_info->{source} //= $field_info->{name};
        my $name = $field_info->{name};
        if (!defined $name) {
          die "config loading failed: field_info with no name in $class_name\n";
        }
        $model_conf->{$class_name}->{field_infos}->{$name} = $field_info;
      }
    }
  }

  # create an annotation_types hash from the annotation_type_list
  if (defined $self->{annotation_type_list}) {
    for my $annotation_type (@{$self->{annotation_type_list}}) {
      if (!defined $annotation_type->{short_display_name}) {
        $annotation_type->{short_display_name} = $annotation_type->{display_name};
      }
      my $annotation_type_name = $annotation_type->{name};
      $self->{annotation_types}->{$annotation_type_name} = $annotation_type;

      $annotation_type->{namespace} //= $annotation_type->{name};
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
           comes from the environment variable POMCUR_CONFIG_LOCAL_SUFFIX, but
           defaults to "deploy"

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

=head2 class_info

 Usage   : my $class_info = $config->class_info($c);
 Function: Return the class information from the Config
 Args    : $c - the Catalyst object
 Returns : the class information hash

=cut
sub class_info
{
  my $self = shift;
  my $c = shift;

  my $model_name = $c->request()->param('model');

  return $self->{class_info}->{$model_name};
}

1;
