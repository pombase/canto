package Canto::Config;

=head1 NAME

Canto::Config - Configuration information for Canto Perl code

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Config

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

use strict;
use warnings;

use Params::Validate qw(:all);
use Config::Any;
use Clone qw(clone);
use JSON;
use Carp;
use Cwd;

use Data::Rmap qw(rmap_to HASH);
use Hash::Merge;

use Canto::DBUtil;
use Canto::TrackDB;
use Canto::Config::ExtensionConf;

use v5.005;

use vars qw($VERSION);

$VERSION = '0.01';

my $app_config_file = "canto.yaml";

=head2 new

 Usage   : my $config = Canto::Config->new(\@file_names);
 Function: Create a new Config object from the given files.  If no files are
           given read from the default application configuration file.

=cut
sub new
{
  my $class = shift;
  my @config_file_names = @{shift // []};
  my $upgrading = shift;

  if (@config_file_names == 0) {
    push @config_file_names, $app_config_file;
  }

  my $config_file_name = shift @config_file_names;
  my $cfg = Config::Any->load_files({ files => [$config_file_name],
                                      use_ext => 1, });

  my ($file_name, $self) = %{$cfg->[0]};

  bless $self, $class;

  for my $config_file_name (@config_file_names) {
    # merge new config
    $self->merge_config([$config_file_name], $upgrading);
  }

  $self->setup($upgrading);

  return $self;
}

=head2 new_test_config

 Usage   : my $config = Canto::Config->new_test_config();
 Function: Create a Config object including the test settings
 Args    : none

=cut
sub new_test_config
{
  my $self = shift;

  my $config = get_config();

  return $self->new([$app_config_file, $config->{test_config_file}]);
}

=head2 merge_config

 Usage   : $config->merge_config(\@config_file_names);
 Function: merge the given config files into a Config object

=cut
sub merge_config
{
  my $self = shift;
  my @file_names = @{shift // []};
  my $upgrading = shift;

  my $cfg = Config::Any->load_files({ files => \@file_names,
                                      use_ext => 1, });

  for my $new_config (map { my ($file_name, $config) = %$_; $config } @$cfg) {
    if (defined $new_config) {
      my $merge = Hash::Merge->new('RIGHT_PRECEDENT');

      my $new_available_annotation_type_list =
        delete $new_config->{available_annotation_type_list};

      my $new = $merge->merge({%$self}, $new_config);

      if (defined $new_available_annotation_type_list) {
        # special case: replace rather than append the new available_annotation_type_list
        $new->{available_annotation_type_list} = $new_available_annotation_type_list;
      }

      %$self = %$new;
    } else {
      # empty file returns undef
    }
  }
}

sub _set_host_organisms
{
  my $self = shift;

  my $track_schema = Canto::TrackDB->new(config => $self);

  $self->{host_organisms} = [];

  my $host_organism_taxonids = $self->{host_organism_taxonids};

  if ($host_organism_taxonids && @$host_organism_taxonids > 0) {
    $self->{pathogen_host_mode} = 1;
    $self->{multi_organism_mode} = 1;

    for my $taxonid (@{$self->{host_organism_taxonids}}) {
      my $rs = $track_schema->resultset('Organismprop')
        ->search({ value => $taxonid,
                   'type.name' => 'taxon_id' },
                 {
                   join => 'type', prefetch => 'organism' });
      if ($rs->count() == 0) {
        die qq|can't find Organism in database for taxon ID "$taxonid"|;
      }

      push @{$self->{host_organisms}}, $rs->first()->organism();
    }
  }
}

sub host_organisms
{
  my $self = shift;

  if (!$self->{host_organisms}) {
    $self->_set_host_organisms()
  }

  return $self->{host_organisms};
}

=head2 setup

 Usage   : $config->setup();
 Function: perform initialisation for this object

=cut
sub setup
{
  my $self = shift;
  my $upgrading = shift;

  if ($self->{extra_config_files}) {
    $self->merge_config($self->{extra_config_files}, $upgrading);
  }

  my @ext_conf = ();

  if ($self->{extension_conf_files}) {
    @ext_conf = Canto::Config::ExtensionConf::parse(@{$self->{extension_conf_files}});
  }

  $self->{extension_configuration} = \@ext_conf;

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
        if (ref $field_info->{source}) {
          $field_info->{db_column_name} = $field_info->{name};
        } else {
          $field_info->{db_column_name} = $field_info->{source};
        }
        my $name = $field_info->{name};
        if (!defined $name) {
          die "config loading failed: field_info with no name in $class_name\n";
        }
        $model_conf->{$class_name}->{field_infos}->{$name} = $field_info;
      }
    }
  }

  my $namespace_term_evidence_codes = $self->{namespace_term_evidence_codes};

  if ($namespace_term_evidence_codes) {
    while (my ($namespace, $ev_configs) = each %$namespace_term_evidence_codes) {
      for my $ev_config (@$ev_configs) {
        my $restriction = $ev_config->{constraint};
        my $ev_codes = $ev_config->{evidence_codes};
        map {
          my $new_ev_code = $_;
          if (!$self->{evidence_types}->{$new_ev_code}) {
            $self->{evidence_types}->{$new_ev_code} = {
              name => $new_ev_code,
            };
          }
        } @$ev_codes;
      }
    }
  }

  # create an inverted map of evidence types so that evidence codes
  # can be looked up by name
  if (my $evidence_types = $self->{evidence_types}) {
    for my $evidence_code (keys %$evidence_types) {
      my $evidence_type_name = $self->{evidence_types}->{$evidence_code}->{name};
      if (!defined $evidence_type_name) {
        $self->{evidence_types}->{$evidence_code}->{name} = $evidence_code;
        $evidence_type_name = $evidence_code;
      }
      $self->{evidence_types_by_name}->{lc $evidence_type_name} =
        $evidence_code;
    }
  }

  delete $self->{export_type_to_allele_type};
  delete $self->{allele_type_names};

  # create allele_types, a hash of allele type names to config, the
  # export_type_to_allele_type map and allele_type_names to make
  # Service::canto_config() simpler
  if (defined $self->{allele_type_list}) {
    for my $allele_type (@{$self->{allele_type_list}}) {
      if ($allele_type->{name} =~ /^wild[ _]?type$/) {
        $allele_type->{autopopulate_name} = $self->{wildtype_name_template};
      }
      if ($allele_type->{name} eq 'deletion') {
        $allele_type->{autopopulate_name} = $self->{deletion_name_template};
      }
      my $export_type = $allele_type->{export_type} // $allele_type->{name};
      push @{$self->{export_type_to_allele_type}->{$export_type}}, $allele_type;
      $self->{allele_types}->{$allele_type->{name}} = $allele_type;
      push @{$self->{allele_type_names}}, $allele_type->{name};
    }
  }

  # create an annotation_types hash from the available_annotation_types and
  # enabled_annotation_type_list
  if (defined $self->{available_annotation_type_list}) {
    my @available_annotation_type_list =
      @{$self->{available_annotation_type_list}};

    my @annotation_type_list = ();

    # default to enabling all annotation types
    if (defined $self->{enabled_annotation_type_list}) {
      my @enabled_annotation_type_list =
        @{$self->{enabled_annotation_type_list}};
      my %enabled_annotation_types = ();
      map {
        $enabled_annotation_types{$_} = 1;
      } @enabled_annotation_type_list;
      @annotation_type_list = map {
        my $name = $_->{name};
        if ($enabled_annotation_types{$name}) {
          ($_);
        } else {
          ();
        }
      } @available_annotation_type_list;
    } else {
      @annotation_type_list = @available_annotation_type_list;
    }

    for my $annotation_type (@annotation_type_list) {
      my $annotation_type_name = $annotation_type->{name};

      if (!$annotation_type->{evidence_codes}) {
        $annotation_type->{evidence_codes} = [];
      }

      for my $ev_code (@{$annotation_type->{evidence_codes}}) {
        if (!exists $self->{evidence_types}->{$ev_code}) {
          $self->{evidence_types}->{$ev_code} = {
            name => $ev_code,
          };

          $self->{evidence_types_by_name}->{lc $ev_code} = $ev_code;
        }
      }

      if (exists $self->{annotation_types}->{$annotation_type_name}) {
        my $merge = Hash::Merge->new('RIGHT_PRECEDENT');
        my $configured_type =
          $self->{annotation_types}->{$annotation_type_name};
        $annotation_type =
          $merge->merge($annotation_type, $configured_type);

        # handle evidence codes differently so codes don't get duplicated
        $annotation_type->{evidence_codes} = $configured_type->{evidence_codes};
        $annotation_type->{term_evidence_codes} = $configured_type->{term_evidence_codes};
      }

      if (!defined $annotation_type->{ontology_size}) {
        $annotation_type->{ontology_size} = 'large';
      }

      if (!defined $annotation_type->{short_display_name}) {
        $annotation_type->{short_display_name} = $annotation_type->{display_name};
      }
      $self->{annotation_types}->{$annotation_type_name} = $annotation_type;

      if ($annotation_type->{category} eq 'ontology') {
        $annotation_type->{namespace} //= $annotation_type->{name};
      }

      my $namespace = $annotation_type->{namespace};

      if (defined $namespace) {
        $self->{annotation_types_by_namespace}->{$namespace} //= [];

        if (!grep {
          $_->{name} eq $annotation_type->{name}
        } @{$self->{annotation_types_by_namespace}->{$namespace}}) {
          push @{$self->{annotation_types_by_namespace}->{$namespace}}, $annotation_type;
        }

        if (!defined $annotation_type->{term_evidence_codes}) {
          $annotation_type->{term_evidence_codes} =
            $self->{namespace_term_evidence_codes}->{$namespace};
        }
      }

      # if an evidence code is not in the main evidence_codes map, add it
      for my $ev_code (@{$annotation_type->{evidence_codes}}) {
        if (!defined $self->{evidence_types}->{$ev_code}) {
          $self->{evidence_types}->{$ev_code} = {
            name => $ev_code,
          };
        }
      }

      # if an evidence code is not in the main evidence_codes map, add it
      for my $ev_code (@{$annotation_type->{evidence_codes}}) {
        if (!defined $self->{evidence_types}->{$ev_code}) {
          $self->{evidence_types}->{$ev_code} = {
            name => $ev_code,
          };
        }
      }

      # if any evidence code for this type needs a with or from field, set
      # needs_with_or_from in the type
      for my $ev_code (@{$annotation_type->{evidence_codes}}) {
        if ($self->{evidence_types}->{$ev_code}->{with_gene}) {
          $annotation_type->{needs_with_or_from} = 1;
          last;
        }
      }
    }

    $self->{annotation_type_list} = [@annotation_type_list];
  }

  my $instance_organism = $self->{instance_organism};

  $self->{multi_organism_mode} = !$instance_organism;

  $self->{host_organism_taxonids} //= [];

  if (@{$self->{host_organism_taxonids}} > 0) {
    $self->{pathogen_host_mode} = 1;
    $self->{multi_organism_mode} = 1;
  } else {
    $self->{pathogen_host_mode} = 0;
  }

  $self->{_strain_species_taxon_map} = {};
  $self->{_reference_strain_taxon_map} = {};

  my %strain_species_map = ();
  if ($self->{species_strain_map}) {
    while (my ($species_taxon_id, $species_details) = each %{$self->{species_strain_map}}) {
      if ($species_details->{reference_strain}) {
        $self->{_reference_strain_taxon_map}->{$species_details->{reference_strain}} =
          $species_taxon_id;
      }
      if ($species_details->{other_strains}) {
        map {
          my $strain_taxon_id = $_;
          $strain_species_map{$strain_taxon_id} = $species_taxon_id;
        } @{$species_details->{other_strains}};
      }
    }
  }
  $self->{_strain_species_taxon_map} = \%strain_species_map;

  my $connect_string = $self->model_connect_string('Track');

  # we need to check that the track db exists in case we're using this
  # Config before a track db is made
  if (defined $connect_string &&
        -f Canto::DBUtil::connect_string_file_name($connect_string) &&
      !$upgrading) {

    my $track_schema = Canto::TrackDB->new(config => $self);

    if (defined $instance_organism) {
      my $taxonid = $instance_organism->{taxonid};

      if (!defined $taxonid) {
        die "instance_organism configuration has no taxonid field";
      }

      my $rs = $track_schema->resultset('Organismprop')
        ->search({ value => $taxonid,
                   'type.name' => 'taxon_id' },
                 {
                   join => 'type' });
      if ($rs->count() > 1) {
        die "matched multiple organismprops with taxonid: $taxonid";
      }

      if ($rs->count() == 0) {
        warn qq(can't find an organism in the DB using taxonid "$taxonid" from ) .
          qq("instance_organism" configuration so this Canto will run in ) .
          qq(multi-organism mode);
        delete $self->{instance_organism};
      } else {
        my $organism = $rs->first()->organism();

        $instance_organism->{organism_id} = $organism->organism_id();
        $instance_organism->{scientific_name} = $organism->scientific_name();

        if ($self->{host_organism_taxonids} && @{$self->{host_organism_taxonids}} > 0) {
          warn "warning: it doesn't make sense to set both " .
            "host_organism_taxonids and instance_organism";
        }
      }
    }
  }
}

=head2

 Usage    : $app_name = Canto::Config::get_application_name();
 Funcation: return the name of this application, based on the Config.pm package
            name (eg. "Canto")

=cut
sub get_application_name
{
  (my $app_name = __PACKAGE__) =~ s/(.*?)::.*/$1/;

  return $app_name;
}

=head2 get_instance_name

 Usage   : my $inst_name = Canto::Config::get_instance_name();
 Function: Return the name of this instance of Canto.  eg. "test" or
           "prod" .  Currently this just return the name of the
           directory that contains the "canto.yaml" file so to have
           multiple instances, have multiple checkouts and name the
           directories uniquely.
 Args    : none

=cut
sub get_instance_name
{
  my $cwd = getcwd();

  if ($cwd =~ m:.*/(.*):) {
    return $1;
  } else {
    return 'root';
  }
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

  my $model_class = "Model::${model_name}Model";

  return undef unless defined $self->{$model_class};

  return $self->{$model_class}->{connect_info}->[0];
}

=head2 get_config

 Usage   : $config = Canto::Config::get_config();
 Function: Get a config object as Catalyst would, by looking for appname.yaml
           and merging the contents with appname_<suffix>.yaml, where <suffix>
           comes from the environment variable CANTO_CONFIG_LOCAL_SUFFIX, but
           defaults to "deploy"

=cut
sub get_config
{
  my %args = @_;
  my $upgrading = $args{upgrading};

  my $lc_app_name = lc get_application_name();
  my $uc_app_name = uc $lc_app_name;

  my $suffix = $ENV{"${uc_app_name}_CONFIG_LOCAL_SUFFIX"};

  my $file_name = "$lc_app_name.yaml";
  my @file_names = ($file_name);

  if (defined $suffix) {
    my $local_file_name = "${lc_app_name}_$suffix.yaml";
    push @file_names, $local_file_name;
  }

  my $config = __PACKAGE__->new(\@file_names, $upgrading);

  return $config;
}

=head2 data_dir_path

 Usage   : my $path = $config->{$key};
 Function: return a value from the configuration hash relative to the
           data_directory
 Args    : $config_key - a key from the hash eg. "ontology_index_dir"
 Returns : eg. "the_data_dir/" . $config{ontology_index_dir}

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

=head2

 Usage   : my $data_dir = $config->data_dir();
 Function: Return the configured data directory
 Args    : none

=cut
sub data_dir
{
  my $self = shift;

  return $self->{data_directory};
}

=head2 class_info

 Usage   : my $class_info = $config->class_info($model_name);
 Function: Return the class information from the Config
 Args    : $model_name - the model to use to select the class_indo
 Returns : the class information hash

=cut
sub class_info
{
  my $self = shift;
  my $model_name = shift;

  if (!defined $model_name) {
    croak "no model_name passed to class_info()";
  }

  return $self->{class_info}->{$model_name};
}

my @boolean_field_names = qw|description_required allele_name_required allow_expression_change can_have_conditions use_select_element|;

sub for_json
{
  my $self = shift;
  my $key = shift;

  my $data = clone $self->{$key};

  rmap_to {
    for my $key (keys %$_) {
      if (grep { $key eq $_; } @boolean_field_names) {
        if ($_->{$key}) {
          $_->{$key} = JSON::true;
        } else {
          $_->{$key} = JSON::false;
        }
      }
    }
  } HASH, $data;

  return $data;
}

=head2 get_species_taxon_of_strain_taxon

 Usage   : my $org_taxon_id = $config->get_species_taxon_of_strain_taxon($strain_taxon_id);
 Function: Given a taxon ID from a strain (eg. 4536 "Oryza sativa f. spontanea"), return
           the taxon species ID of the species (eg. 4530 "Oryza sativa").  The mapping
           is configured by "species_strain_map" in the config file
 Returns : The species taxon ID or undef if the strain taxon ID isn't in the map.

=cut


sub get_species_taxon_of_strain_taxon
{
  my $self = shift;

  my $strain_taxon_id = shift;

  return $self->{_strain_species_taxon_map}->{$strain_taxon_id} //
    $self->{_reference_strain_taxon_map}->{$strain_taxon_id};
}


=head2 get_annotation_type_by_name

 Usage   : my $annotation_type_config =
              $config->get_annotation_type_by_name("molecular_function");
 Function: Get the configuration for a type
 Returns : a hash of annotation type details

=cut

sub get_annotation_type_by_name
{
  my $self = shift;

  my $annotation_type_name = shift;

  return $self->{annotation_types}->{$annotation_type_name};
}

1;
