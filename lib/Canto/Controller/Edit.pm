package Canto::Controller::Edit;

=head1 NAME

Canto::Controller::Edit - controller to handler /edit/... requests

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Controller::Edit

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
use Carp;

use base 'Catalyst::Controller::HTML::FormFu';

use Moose;

use Canto::DBLayer::Path;
use Canto::Util qw(trim);

with 'Canto::Role::CheckACL';

my $MAX_VALUE_LENGTH = 50;

sub _get_field_values
{
  my $c = shift;
  my $referenced_table_name = shift;
  my $referenced_class_name = shift;
  my $select_values = shift;
  my $field_info = shift;
  my $type = shift;

  my $model_name = $c->request()->param('model');
  my $class_info =
    $c->config()->class_info($model_name)->{$referenced_table_name};
  my $field_name = $class_info->{display_field};

  my $db_field_column =
    $class_info->{field_infos}->{$field_name}->{source} // $field_name;
  my $values_constraint = $field_info->{values_constraint};

  my $constraint_path = undef;
  my $constraint_value = undef;
  my $where_constraint = undef;

  # constrain the possible values shown in the list by using the
  # values_constraint from the config file
  if (defined $values_constraint) {
    if ($values_constraint =~ /where (.*)/) {
      $where_constraint = $1;
    } else {
      my $pattern = qr|^\s*(.*?)\s*=\s*"(.*)"\s*$|;
      if ($values_constraint =~ /$pattern/) {
        $constraint_path = Canto::DBLayer::Path->new(path_string => $1);
        $constraint_value = $2;
      } else {
        die "values_constraint '$values_constraint' doesn't match " +
          "pattern: $pattern\n";
      }
    }
  }

  my $rs = $c->schema()->resultset($referenced_class_name)
    ->search(\[$where_constraint]);

  my @res = ();

  while (defined (my $row = $rs->next())) {
    if (defined $constraint_path) {
      my $this_constrain_value = $constraint_path->resolve($row);
      next unless $constraint_value eq $this_constrain_value;
    }

    # multi-column primary keys aren't supported
    my $table_pk_column = ($row->primary_columns())[0];

    my $value = $row->$table_pk_column();
    my $label = $row->$db_field_column();

    if (defined $label) {
      if (length $label > $MAX_VALUE_LENGTH) {
        $label =~ s/(.{$MAX_VALUE_LENGTH}).*/$1 .../;
      }
    } else {
      $label = '[...]';
    }

    my $option = { value => $value, label => $label };

    if (grep { $row->$table_pk_column() eq $_ } @$select_values) {
      if ($type eq 'Select') {
        $option->{attributes} = { selected => 't' };
      } else {
        $option->{attributes} = { checked => 't' };
      }
    }

    push @res, $option;
  }

  return @res;
}

# the names of buttons in the form so we can skip them later
my @INPUT_BUTTON_NAMES = qw(submit cancel);

# get the default value (if configured) by eval()ing the default_value
# field from the configuration file
sub _get_default_value
{
  my $c = shift;
  my $field_info = shift;

  my $default_value_code = $field_info->{default_value};

  if (defined $default_value_code) {
    my $result = eval "$default_value_code";
    if ($@) {
      my $field_label = $field_info->{name};
      warn "error evaluating default_value configuration for "
        . "'$field_label': $@";
    } else {
      return $result;
    }
  }

  return undef;
}

# return the default value to use for the field given by $field_info
sub _get_default_ref_value
{
  my $c = shift;
  my $field_info = shift;
  my $referenced_class_name = shift;

  my $referenced_table = Canto::DB::table_name_of_class($referenced_class_name);

  # try to find the default value from the configuration file
  my $default_value = _get_default_value($c, $field_info);

  if (defined $default_value) {
    # look up the display name and find the object_id
    my $model_name = $c->request()->param('model');
    my $ref_table_info =
      $c->config()->class_info($model_name)->{$referenced_table};
    my $ref_display_field = $ref_table_info->{display_field};
    my $ref_default_obj;

    eval "require $referenced_class_name";

    if ($referenced_class_name->has_column($ref_display_field)) {
      $ref_default_obj = $c->schema()->resultset($referenced_class_name)->
        find({ $ref_display_field, $default_value });
    } else {
      # display name isn't a column (eg. Person::full_name()) so iterate instead
      my $rs = $c->schema()->resultset($referenced_class_name);

      while (defined (my $row = $rs->next())) {
        if ($row->$ref_display_field() eq $default_value) {
          $ref_default_obj = $row;
        }
      }
    }
    if (defined $ref_default_obj) {
      my $table_pk_column = ($ref_default_obj->primary_columns())[0];

      return $ref_default_obj->$table_pk_column();
    } else {
      die "Default value ($default_value) not found in "
        . "table $referenced_table.$ref_display_field\n";
    }
  }
}

sub _make_display_label
{
  my $display_field_label = shift;

  $display_field_label =~ s/_id$//;
  $display_field_label =~ s/_/ /g;

  return $display_field_label;
}

sub _init_form_field
{
  my $c = shift;
  my $field_info = shift;
  my $object = shift;
  my $type = shift;

  my $schema = $c->schema();

  my $field_name = $field_info->{name};

  my $display_field_label = _make_display_label($field_name);

  my $field_db_column = $field_name;

  if (defined $field_info->{source}) {
    $field_db_column = $field_info->{source};
  }

  my $elem = {
    name => $field_name, label => $display_field_label
  };

  if (!$field_info->{editable}) {
    $elem->{attributes}->{readonly} = 1;
  }

  my $class_name = $schema->class_name_of_table($type);
  my $db_source = $schema->source($class_name);

  my $info_ref = $class_name->relationship_info($field_db_column);

  #to handle Chado style foreign keys like "type_id" (rather than "type")
  (my $field_without_id = $field_db_column) =~ s/_id//;

  if (!defined $info_ref) {
    $info_ref = $class_name->relationship_info($field_without_id);
  }

  if (defined $info_ref && $info_ref->{attrs}->{is_foreign_key_constraint}) {
    my %info = %{$info_ref};
    my $referenced_class_name = $info{class};

    my $referenced_table = Canto::DB::table_name_of_class($referenced_class_name);

    if (!defined $field_name) {
      die "no display_key_fields configuration for $referenced_table\n";
    }

    $elem->{type} = 'Select';

    my $current_value = undef;
    if (defined $object && defined $object->$field_db_column()) {
      my $other_object = $object->$field_without_id();
      my $table_pk_column = ($other_object->primary_columns())[0];

      $current_value = $other_object->$table_pk_column();
    } else {
      $current_value = $c->req->param("$field_db_column.id");

      if (!defined $current_value) {
        $current_value = _get_default_ref_value($c, $field_info, $referenced_class_name);
      }
    }

    my @current_values = ();

    if (defined $current_value) {
      push @current_values, $current_value;
    }

    $elem->{options} = [_get_field_values($c, $referenced_table,
                                          $referenced_class_name,
                                          [@current_values], $field_info,
                                          'Select')];

    my $field_is_nullable = $db_source->column_info($field_db_column)->{is_nullable};

    if ($field_is_nullable) {
      # add a blank to the select list if this field can be null
      unshift @{$elem->{options}}, [0, ''];
    }
  } else {
    if ($field_info->{is_collection} ||
          (defined $info_ref && $info_ref->{attrs}->{join_type})) {
      my $referenced_class_name;

      if (defined $info_ref) {
        $referenced_class_name = $info_ref->{class};
      } else {
        $referenced_class_name = $field_info->{referenced_class};
      }

      my $referenced_table = Canto::DB::table_name_of_class($referenced_class_name);

      $elem->{type} = 'Checkboxgroup';

      my @current_values = ();
      if (defined $object) {
        my $rs = $object->$field_db_column();
        while (defined (my $row = $rs->next())) {
          my $row_pk_field = ($row->primary_columns())[0];
          push @current_values, $row->$row_pk_field();
        }
      } else {
        push @current_values, $c->req->param("$referenced_table.id");
      }

      $elem->{options} = [_get_field_values($c, $referenced_table,
                                            $referenced_class_name,
                                            [@current_values], $field_info,
                                            'Checkboxgroup')];
    } else {
      my $model_name = $c->request()->param('model');

      my $column_info =
        $schema->source($class_name)->column_info($field_db_column);
      my $attribute_type = $column_info->{data_type};

      if ($attribute_type eq 'boolean') {
        $elem->{type} = 'Checkbox';
      } else {
        $elem->{type} = 'Text';
      }
      if (!$db_source->column_info($field_db_column)->{is_nullable}) {
        $elem->{constraints} = [ { type => 'Length',  min => 1 }, 'Required' ];
      }
      if (defined $object) {
        if ($attribute_type eq 'boolean') {
          if ($object->$field_db_column()) {
            $elem->{attributes}->{checked} = "checked";
          }
        } else {
          $elem->{value} = $object->$field_db_column();
        }
      } else {
        my $param_default_value = $c->req->param("object.$field_db_column");

        if (defined $param_default_value) {
          $elem->{value} = $param_default_value;
        } else {
          my $default_value = _get_default_value($c, $field_info);
          if (defined $default_value) {
            $elem->{value} = $default_value;
          }
        }
      }
    }
  }

  return $elem;
}

# Initialise the form using the list of field_infos in the config file.
# Attributes will be rendered as text areas, references as pop ups.
sub _initialise_form
{
  my $c = shift;
  my $object = shift;
  my $type = shift;
  my $form = shift;

  my @elements = ();

  my $model_name = $c->request()->param('model');
  my $field_infos_ref =
    $c->config()->class_info($model_name)->{$type}->{field_info_list};
  my @field_infos;

  if (defined $field_infos_ref) {
    @field_infos = @$field_infos_ref;
  } else {
    @field_infos = ();
  }

  for my $field_info (@field_infos) {
    if ((!$field_info->{admin_only} ||
         $c->user_exists() && $c->user()->role()->name() eq 'admin') &&
        $c->schema()->column_type($field_info, $type) ne 'computed') {
      push @elements, _init_form_field($c, $field_info, $object, $type);
    }
  }

  $form->default_args({elements => { Text => { size => 50 } } });

  $form->auto_fieldset(1);

  my $separator_block;

  if (@field_infos) {
    $separator_block = { name => 'clear-div', type => 'Block',
                         attributes => { style => 'clear: both;' } };
  } else {
    $separator_block = {
      name => 'clear-div', type => 'Block',
      attributes => { style => 'clear: both;' },
      content => qq([No editable fields configured for type "$type"])
     };
  }

  my @model_names = $c->request()->param('model');

  my $model_element = {
    # must be "model_name" rather than "model" or FormFu will conclude that
    # the form has been submitted
    type => 'Hidden', name => 'model_name',
    value => $model_names[0]
  };

  my @all_elements = (@elements,
                      $model_element,
                      $separator_block,
                      map { {
                        name => $_, type => 'Submit', value => ucfirst $_,
                        attributes => { class => 'button' },
                      } } @INPUT_BUTTON_NAMES,
                     );

  $form->elements([@all_elements]);
}

sub _create_object {
  my $c = shift;
  my $table_name = shift;
  my $form = shift;

  my $schema = $c->schema();

  my $class_name = $schema->class_name_of_table($table_name);

  my $model_name = $c->request()->param('model');
  my $class_info_ref =
    $c->config()->class_info($model_name)->{$table_name};
  if (!defined $class_info_ref) {
    croak "can't find configuration for editing $table_name objects\n";
  }

  my %form_params = %{$form->params()};
  my %object_params = ();

  for my $name (keys %form_params) {
    if (grep { $_ eq $name } (@INPUT_BUTTON_NAMES, 'model_name')) {
      next;
    }

    my $field_info_ref = $class_info_ref->{field_infos}->{$name};
    my %field_info = %{$field_info_ref};

    next if $field_info{is_collection};

    my $field_db_column = $name;

    if (defined $field_info{source}) {
      $field_db_column = $field_info{source};
    }

    my $value = $form_params{$name};

    if ($field_db_column =~ /(.*)_id$/) {
      # hack to cope with references ending in "_id", we need to remove the
      # suffix and use the object as the value
      $field_db_column = $1;
      my $referenced_class_name = $field_info{referenced_class};

      $value = $schema->resultset($referenced_class_name)->find($value);
    }

    my $info_ref = $class_name->relationship_info($field_db_column);

    if (defined $info_ref && $value == 0) {
      # special case for undefined references which are represented in the form
      # as a 0
      $value = undef;
    } else {
      if ($value =~ /^\s*$/) {
        # if the user doesn't enter anything, use undef
        $value = undef;
      }
    }

    $object_params{$field_db_column} = $value;
  }

  my $existing_object = $schema->resultset($class_name)->find({ %object_params });

  if (defined $existing_object) {
    return ($existing_object, 1);
  } else {
    my $object = $schema->create_with_type($class_name, { %object_params });

    # set collections - this is a hack because the other fields will be set for a
    # second time
    return (_update_object($c, $object, $form), 0);
  }
}

# update the object based on the form values
sub _update_object {
  my $c = shift;
  my $object = shift;
  my $form = shift;

  my $schema = $c->schema();

  my %form_params = %{$form->params()};

  my $type = $object->table();
  my $class_name = $schema->class_name_of_table($type);

  my $model_name = $c->request()->param('model');
  my $class_info_ref = $c->config()->class_info($model_name)->{$type};

  my %field_infos = %{$class_info_ref->{field_infos}};

  my @form_fields = keys %form_params;

  # special case for setting collections - if nothing is selected then nothing
  # is sent in the form.  We'd like to clear the collection in that case so we
  # make sure that all collections are processed
  for my $field_label (keys %field_infos) {
    if (grep { $_ eq $field_label } @form_fields) {
      next;
    }

    push @form_fields, $field_label;
  }

  for my $name (@form_fields) {
    if (grep { $_ eq $name } (@INPUT_BUTTON_NAMES, 'model_name')) {
      next;
    }

    my $field_info_ref = $field_infos{$name};
    my %field_info = %{$field_info_ref};

    my $field_db_column = $name;

    if (defined $field_info{source}) {
      $field_db_column = $field_info{source};
    }

    my $value = $form_params{$name};
    my $info_ref = $object->relationship_info($field_db_column);

    if (!defined $info_ref) {
      (my $short_db_column_name = $field_db_column) =~ s/_id$//;
      $info_ref = $object->relationship_info($short_db_column_name);
    }

    if (defined $info_ref && $value == 0) {
      # special case for undefined references which are represented in the form
      # as a 0
      $value = undef;
    }

    my $column_type = $schema->column_type(\%field_info, $type);

    if ($column_type eq 'collection') {
      # special case for collections, we need to look up the objects
      my $referenced_class_name;

      if (defined $info_ref) {
        $referenced_class_name = $info_ref->{class};
      } else {
        $referenced_class_name = $field_info{referenced_class};
      }

      my $referenced_table = Canto::DB::table_name_of_class($referenced_class_name);

      my @values;

      if (defined $value) {
        if (ref $value) {
          @values = @$value;
        } else {
          @values = ($value);
        }

      } else {
        @values = ();
      }

      @values = map {
        $c->schema()->find_with_type($referenced_class_name,
                                     "${referenced_table}_id" => $_);
      } @values;

      if (defined $info_ref) {
        # there don't seem to be set_* methods for the has_many case, so delete
        # contents of the collection and set the references instead
        my $other_set_meth = $object->table();
        my $rs_meth = $field_db_column;
        my $other_rs = $object->$rs_meth();
        while (defined (my $other_obj = $other_rs->next())) {
          if (grep {
                my $other_id_field = $referenced_table . '_id';
                $_->$other_id_field() eq $other_obj->$other_id_field();
              } @values) {
            next;
          }

          $other_obj->$other_set_meth(undef);
          $other_obj->update();
        }

        for my $other_obj (@values) {
          my $object_id_col = $type . '_id';
          $other_obj->$other_set_meth($object->$object_id_col());
          $other_obj->update();
        }
      } else {
        my $set_meth = "set_$field_db_column";
        $object->$set_meth(\@values);
      }
    } else {
      if ($column_type eq 'attribute') {
        my $column_info = $object->result_source()->column_info($field_db_column);
        my $attribute_type = $column_info->{data_type};
        if ($attribute_type eq 'boolean') {
          $object->$field_db_column(defined $value &&
                                    ($value eq 1 || lc $value eq 'on' ||
                                     lc $value eq 'yes'));
        } else {
          if (defined $value) {
            $value = trim($value);
          }
          $object->$field_db_column($value || undef);
        }
      } else {
        # can't set computed columns
      }
    }
  }

  $object->update();
}

sub _check_auth
{
  my $self = shift;
  my $c = shift;

  if (!$self->check_access($c)->{edit}) {
    $c->stash()->{error} = "Log in to allow editing";
    $c->forward('/front');
    $c->detach();
    return;
  }
}

sub _run_create_hook
{
  my $c = shift;
  my $object = shift;
  my $type = $object->table();

  my $model_name = $c->request()->param('model');
  my $class_info_ref =
    $c->config()->class_info($model_name)->{$type};

  if (defined $class_info_ref) {
    my $pre_create_hook =
      $class_info_ref->{pre_create_hook};

    if (defined $pre_create_hook) {
      no strict 'refs';
      (my $hook_class_name = $pre_create_hook) =~
        s/(.*)::.*/$1/;
      eval "require $hook_class_name";
      if ($@) {
        croak "couldn't find class ($hook_class_name)"
          . " for pre_create_hook: $pre_create_hook\n";
      }
      &{$pre_create_hook}($c, $object);
    }
  }

}

# create or edit an object based on the value of the $req_type argument
sub object : Global {
  my ($self, $c, $req_type, $type, $object_id) = @_;
  my $schema = $c->schema();
  my $object = undef;

  my $st = $c->stash;

  $self->_check_auth($c);

  my $class_name = $schema->class_name_of_table($type);

  if (defined $object_id) {
    $object = $schema->find_with_type($class_name, "${type}_id" => $object_id);
  }

  my $display_type_name = $schema->display_name($type);

  if ($req_type eq 'new') {
    $st->{title} = "New $display_type_name";
  } else {
    $st->{title} = "Edit $display_type_name";
  }

  $st->{template} = "edit.mhtml";

  my $form = $self->form;

  my $model_name =
    $c->req()->param('model') || $form->param_value('model_name');

  _initialise_form($c, $object, $type, $form);

  $form->process;

  $c->stash->{form} = $form;

  if ($form->submitted() && defined $c->req->param('cancel')) {
    if ($req_type eq 'new') {
      $c->res->redirect($c->uri_for("/"));
      $c->detach();
    } else {
      $c->res->redirect($c->uri_for("/view/object/$type/$object_id",
                                      {
                                        model => $model_name
                                      }));
      $c->detach();
    }
  }

  if ($form->submitted_and_valid()) {
    my $exists = undef;

    if ($req_type eq 'new') {
      $schema->txn_do(sub {
                        ($object, $exists) = _create_object($c, $type, $form);
                      });

      # multi-column primary keys aren't supported
      my $table_pk_field = ($object->primary_columns())[0];

      # get the id so we can redirect below
      $object_id = $object->$table_pk_field();
    } else {
      $schema->txn_do(sub {
                 _update_object($c, $object, $form);
                           });
    }

    (my $short_class_name = $class_name) =~ s/.*:://;
    if ($exists) {
      $c->stash()->{error} =
        "Couldn't add the $short_class_name - that $short_class_name already exists";
    } else {
      $c->flash()->{notice} = "$short_class_name added";
      $c->res->redirect($c->uri_for("/view/object/$type/$object_id",
                                    {
                                      model => $model_name
                                    }));
      $c->detach();
    }
  }
}

=head2

 Usage   : called by Catalyst
 Function: Create a new object from the parameters, without going to a form
           first, redirecting to the object page
 Args    : type - the table for the new object

=cut

sub create : Global Args(1) {
  my ($self, $c, $type) = @_;

  $self->_check_auth($c);

  my %params = %{$c->request()->params()};

  delete $params{model};

  my $model_name = $c->req()->param('model');
  my $schema = $c->schema();
  my $class = $schema->class_name_of_table($type);

  my $new_object;

  my $process = sub {
    $new_object = $schema->create_with_type($class, { %params });

    _run_create_hook($c, $new_object);
  };

  $schema->txn_do($process);

  my $object_id = Canto::DB::id_of_object($new_object);

  $c->res->redirect($c->uri_for("/view/object/$type/$object_id",
                                {
                                  model => $model_name
                                }));
  $c->detach();
}

1;
