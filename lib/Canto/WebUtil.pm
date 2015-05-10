package Canto::WebUtil;

=head1 NAME

Canto::WebUtil - Utilities for the web code

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::WebUtil

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
use Carp;

use Canto::DB;
use Canto::DBLayer::Path;
use Number::Format;

sub _format_field_value
{
  my $col_conf = shift;
  my $field_value = shift;
  my $attribute_type = shift;

  my $fmt = Number::Format->new();

  my $format_def = $col_conf->{format} // $attribute_type;

  if ($format_def eq 'boolean') {
    if ($field_value) {
      return 'yes';
    } else {
      return 'no';
    }
  }

  if (defined $field_value && defined $format_def) {
    if (ref $format_def) {
      if ($format_def->{type} eq 'perl') {
        eval $format_def->{code};
        if ($@) {
          warn "error eval()ing ", $format_def->{code}, ": $@\n";
          $field_value = '[configuration error]';
        }
      } else {
        die "unknown column format, ", Dumper([$format_def]), "\n";
      }
    } else {
      if ($format_def eq 'integer') {
        if ($field_value =~ /^\d+$/) {
          return $fmt->format_number($field_value);
        } else {
          return 0;
        }
      } else {
        if ($format_def =~ /\%/) {
          return 0 unless $field_value;
          return sprintf $format_def, $field_value;
        } else {
          if ($format_def eq 'text' || $format_def eq 'varchar' ||
              $format_def eq 'timestamp') {
            # fall through
          } else {
            die "unknown column format: $format_def\n";
          }
        }
      }
    }
  }

  return $field_value // $col_conf->{default};
}

sub _get_cached_object
{
  my $schema = shift;
  my $object = shift;
  my $db_column_name = shift;
  my $table_name = shift;
  my $cache = shift;

  my $col_object_id = $object->get_column($db_column_name);

  if (!defined $col_object_id) {
    return undef;
  }
  my $cache_key = "$table_name.$col_object_id";

  if (!defined $cache || !exists $cache->{$cache_key}) {
    (my $column_name = $db_column_name) =~ s/_id$//;
    my $value = $object->$column_name();
    if (defined $cache) {
      $cache->{$cache_key} = $value;
    } else {
      return $value;
    }
  }
  return $cache->{$cache_key};
}

=head2

 Usage   : my ($field_value, $field_type, $ref_class_info,
               $ref_display_key, $attribute_type) =
             Canto::WebUtil::get_field_value($c, $object, $class_info,
                                              $field_name);
 Function: Get the real value of a field, for display.  The value may be
           straight from the database column, or may be created with Perl code
           in the source key of the configuration.
 Args    : $c - the Catalyst context
           $object - the object
           $field_name - The name of the field to look up
 Return  : $field_value - the value of the field or display or use.  If it is a
                          foreign key the whole object that is returned
           $field_type - can be:
                            'table_id': the id column of this table
                            'foreign_key': this field is a foreign key
                            'attribute': this is a plain attribute field
                            'key_field': this is the attribute field that is the
                               natural primary key for this class
                            'method': $field_name is a method name on the object,
                               which will be called and it's value returned
           $ref_class_info - the configuration for the referenced object
           $attribute_type - if $field_type is 'attribute' this is the data type
                             ('integer', 'text', 'boolean', ...)

 Note    : This function uses the field_infos section of the configuration and
           uses the source field (if present) to get the field value
              eg.  { name => 'name' }  # read from the name column
              eg.  { name => 'Sample name',
                     source => 'samplename',   # use the samplename column
                   }
              or   { name => 'Half size',
                     source => { perl => '$object->size() / 2' },  # Perl code
                     format => '%6.2f'              # format with sprintf
                   }
              or   { name => 'Big count',
                     source => { perl => '$object->count() + 100' },
                     format => integer   # format as integer and right align
                   }

=cut
sub get_field_value
{
  my $c = shift;
  my $object = shift;
  my $class_info = shift;
  my $field_name = shift;
  my $cache = shift;

  my $type = $class_info->{source};

  if ($field_name eq "${type}_id") {
    return ($object->$field_name(), 'table_id', undef);
  }

  my $model_name = $c->request()->param('model');
  my $class_infos = $c->config()->class_info($model_name);
  my $col_conf = $class_info->{field_infos}->{$field_name};

  if (!defined $col_conf) {
    if ($object->can($field_name)) {
      return ($object->$field_name(), 'method', undef);
    } else {
      warn "no field_info configured for field '$field_name' in $class_info->{name}\n";
    }
  }

  my $schema = $c->schema();

  if (defined $col_conf->{source} && ref $col_conf->{source} eq 'HASH') {
    if (defined $col_conf->{source}->{perl}) {
      my $field_value = eval $col_conf->{source}->{perl};
      if ($@) {
        $field_value = $@;
        warn "$@\n";
      }

      return ($field_value, 'attribute', undef);
    } else {
      if (defined $col_conf->{source}->{sql}) {
        my $col_value = $object->get_column($field_name);
        if (defined $col_value && defined $col_conf->{referenced_class}) {
          my $referenced_table = Canto::DB::table_name_of_class($col_conf->{referenced_class});
          my $referenced_object =
            $schema->resultset($col_conf->{referenced_class})->find({ $referenced_table . "_id" => $col_value });
          if (defined $referenced_object) {
            my $ref_table_conf = $class_infos->{$referenced_table};
            if (!defined $ref_table_conf) {
              die "no class_info configuration for $referenced_table\n";
            }
            my $primary_key_name = $ref_table_conf->{display_field};
            return ($referenced_object, 'foreign_key', $primary_key_name);
          }
        } else {
          return ($col_value // $col_conf->{default}, 'attribute', undef);
        }
      } else {
        use Data::Dumper;
        die "source not understood: ", Dumper([$col_conf->{source}]), "\n";
      }
    }
  }

  my $parent_class_name = $schema->class_name_of_table($type);

  if ($schema->column_type($col_conf, $type) eq 'collection') {
    return (undef, 'collection');
  }

  my $field_db_column = $col_conf->{source};

  $field_db_column =~ s/_id$//;

  my $info_ref = $parent_class_name->relationship_info($field_db_column);

  if (!defined $info_ref) {
    my $short_field = $field_db_column;
    $short_field =~ s/_id//;
    $info_ref = $parent_class_name->relationship_info($short_field);
  }


  if (defined $info_ref) {
    my %info = %{$info_ref};

    my $referenced_class_name = $info{class};
    my $referenced_table = Canto::DB::table_name_of_class($referenced_class_name);

    my $field_value =
      _get_cached_object($schema, $object, $col_conf->{source}, $referenced_table, $cache);

    if (defined $field_value) {
      my $ref_table_conf = $class_infos->{$referenced_table};
      if (!defined $ref_table_conf) {
        die "no class_info configuration for $referenced_table\n";
      }

      my $primary_key_name = $ref_table_conf->{display_field};

      if (!defined $primary_key_name) {
        die "no display_field configuration for $referenced_table\n";
      }

      return ($field_value, 'foreign_key', $primary_key_name);
    } else {
      return (undef, 'foreign_key', undef);
    }
  } else {
    my $field_value = $object->$field_db_column();
    my $display_key_field = $class_infos->{$type}->{display_field};

    my $return_type;

    if (defined $display_key_field &&
        $field_name eq $display_key_field) {
      $return_type = 'key_field';
    } else {
      $return_type = 'attribute';
    }

    my $column_info = $object->result_source()->column_info($field_db_column);
    my $attribute_type = $column_info->{data_type};

    return (_format_field_value($col_conf, $field_value, $attribute_type),
            $return_type, undef, $attribute_type);
  }
}

sub process_rs_options
{
  my $rs = shift;
  my $column_confs = shift;

  my @column_options = ();

  for my $conf (@$column_confs) {
    my $source = $conf->{source};

    next unless defined $source;
    next unless ref $source eq 'HASH' && defined $source->{sql};

    my $field_name = $conf->{name};

    push @column_options, { $conf->{name}, \(qq|($source->{sql}) as "$field_name"|) };
  }

  return $rs->search(undef, { '+columns' => [@column_options] });
}

=head2

 Usage   : my @column_confs =
             Canto::WebUtil::get_column_confs($c, $rs, $config_info)
 Function: Return the column configuration for displaying the given object, from
           the configuration file (if columns are configured for this type) or
           by creating a default configuration
 Args    : $c - the Catalyst context
           $object - the object
           $config_info - the configuration discribing the columns
           $context - where in the application these fields will be shown,
                      can be: "list", "summary", "inline_list" or undef.
                      If this context matches the hide_context
                      configuration for a field it won't be included in
                      the returned list
 Return  : column configurations in the same format as described in
           get_field_value() above

=cut
sub get_column_confs
{
  my $c = shift;
  my $schema = $c->schema();
  my $config = $c->config();
  my $rs = shift;
  my $config_info = shift;
  my $context = shift;

  my $role;

  if ($c->user_exists()) {
    $role = $c->user()->role()->name();
  }

  my $table = $config_info->{source};

  my @column_confs = ();

  for my $conf (@{$config_info->{field_info_list}}) {
    my $field_db_column = $conf->{source} || $conf->{name};

    if ($schema->column_type($conf, $table) eq 'collection') {
      next;
    }

    if ($conf->{admin_only}) {
      next unless defined $role && $role eq 'admin';
    }

    my $hide_context = $conf->{hide_context};

    if (defined $hide_context && defined $context) {
      if (ref $hide_context) {
        if (grep { $_ eq $context } @$hide_context) {
          next;
        }
      } else {
        if ($hide_context eq $context) {
          next;
        }
      }
    }

    push @column_confs, $conf;
  }

  if (!@column_confs) {
    for my $column_name ($rs->result_source->columns()) {
      next if $column_name eq 'created_stamp';
      if ($column_name =~ /(.*)_id$/) {
        next if $1 eq $table;
      }
      push @column_confs, { name => $column_name };
    }
  }

  return @column_confs;
}

sub _process_path
{
  my $path_string = shift;
  my $object = shift;

  if (!defined $object) {
    croak "no object didn't resolve in _process_path()";
  }

  my $post_process = undef;

  if ($path_string =~ /^([^:]+):(.*)/) {
    $path_string = $1;
    $post_process = $2;
  }

  my $path = Canto::DBLayer::Path->new(path_string => $path_string);

  my $res = $path->resolve($object);

  if (defined $post_process) {
    # alias $res to $_
    for ($res) {
      $res = eval $post_process;
      if ($@) {
        warn qq(post-process "$post_process" failed for path ) .
          qq("$path_string" failed: $_\n);
      }
    }
  }

  if (!defined $res) {
    croak qq(path "$path_string" resolved to undef);
  }

  return $res;
}

=head2 substitute_paths

 Usage   : my $new_str = Canto::WebUtil::substitute_paths($template, $object);
 Function: Use $object to replace the paths in the $template.  Paths look
           like @@something->something_else@@.  eg for a Person $object with
           a name of "John Smith" and a role of "user", that has a lab field
           that refers to a Lab with the name "Big Lab" this template:
             "person name: @@name@@, role: @@role@@, lab name: @@lab->name@@"
           A path may optionally be followed by ":<perl_code>", where the
           <perl_code> can operate on the result of evaluating the path (stored
           in $_ and return an altered result. eg.
             "name: @@lab->name:uc@@"
           will return a string with an uppercase version of the lab name.
           To use a regexp substitution use the "r" modifier. eg.
             "name: @@lab->name:s/Group/Lab/r@@"
 Args    : $template - a template containing paths that can be resolved with
                       Canto::DBLayer::Path::resolve()
           $object - the object that will be passed to Path::resolve()
 Returns : the substituted string

=cut
sub substitute_paths
{
  my $string = shift;
  my $object = shift;

  if (!defined $object) {
    croak "no object passed to substitute_paths()";
  }

  $string =~ s/\@\@([^@]+)\@\@/_process_path($1, $object)/eg;

  return $string;
}

=head2 escape_inline_js

 Usage   : $res = Canto::WebUtil::escape_inline_js($string);
 Function: Escape a string so that it can be used in an
           inline "javascript:" string.
 Args    : $string - the string
 Returns : The input string with problematic characters escaped

=cut
sub escape_inline_js
{
  my $string = shift;

  $string =~ s/&/&amp;/gs;
  $string =~ s/\\/\\\\/gs;
  $string =~ s/\n/\\n/gs;
  $string =~ s/\r/\\r/gs;
  $string =~ s/\t/\\t/gs;
  $string =~ s/'/\\'/gs;
  $string =~ s/"/&quot;/gs;
  $string =~ s/</&lt;/gs;
  $string =~ s/>/&gt;/gs;

  return $string;
}

=head2 nowrap_words

 Usage   : my $text = Canto::WebUtil::nowrap_words($text);
 Function: Force wrapping only at whitespaces by adding nowrap spans around
           all text

=cut

sub nowrap_words
{
  my $text = shift;
  return $text =~ s|(\S+)|<span style="white-space: nowrap;">$1</span>|gr;
}

1;
