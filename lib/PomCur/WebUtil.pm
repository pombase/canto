package PomCur::WebUtil;

=head1 NAME

PomCur::WebUtil - Utilities for the web code

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::WebUtil

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

use PomCur::DB;

=head2

 Usage   : my ($field_value, $field_type) =
             PomCur::WebUtil::get_field_value($c, $object, $col_conf);
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
           $ref_display_key - the display key of the referenced object
                              (or undef)

 Note    : This function uses the field_infos section of the configuration and
           uses the source field (if present) to get the field value
              eg.  { name => 'longname' }  # read from the longname column
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
  my $field_name = shift;

  my $type = $object->table();

  if ($field_name eq "${type}_id") {
    return ($object->$field_name(), 'table_id', undef);
  }

  my $class_infos = $c->config()->{class_info};
  my $col_conf = $class_infos->{$type}->{field_infos}->{$field_name};

  if (!defined $col_conf) {
    croak "no field_info configured for field '$field_name' of $type\n";
  }

  if (defined $col_conf->{source} && $col_conf->{source} =~ /[\$\-<>\';]/) {
    # it looks like Perl code, so eval it
    my $field_value = eval $col_conf->{source};
    if ($@) {
      $field_value = $@;
      warn "$@\n";
    }

    return ($field_value, 'attribute', undef);
  }

  my $schema = $c->schema();
  my $parent_class_name = $schema->class_name_of_table($type);

  if ($schema->column_type($col_conf, $type) eq 'collection') {
    return (undef, 'collection');
  }

  my $field_db_column = $col_conf->{source};

  $field_db_column =~ s/_id$//;

  my $field_value = $object->$field_db_column();

  my $info_ref = $parent_class_name->relationship_info($field_db_column);

  if (!defined $info_ref) {
    my $short_field = $field_db_column;
    $short_field =~ s/_id//;
    $info_ref = $parent_class_name->relationship_info($short_field);
  }

  if (defined $info_ref) {
    my %info = %{$info_ref};
    my $referenced_object = $object->$field_db_column();

    if (defined $referenced_object) {
      my $referenced_class_name = $info{class};
      my $referenced_table = PomCur::DB::table_name_of_class($referenced_class_name);

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
    my $display_key_field = $class_infos->{$type}->{display_field};

    if (defined $display_key_field && $field_db_column eq $display_key_field) {
      return ($field_value, 'key_field', undef);
    } else {
      return ($field_value, 'attribute', undef);
    }
  }
}

=head2

 Usage   : my @column_confs =
             PomCur::WebUtil::get_column_confs_from_object($config, $user_role, $object)
 Function: Return the column configuration for displaying the given object, from
           the configuration file (if columns are configured for this type) or
           by creating a default configuration
 Args    : $c - the Catalyst context
           $user_role - the role of the current user
           $object - the object
 Return  : column configurations in the same format as described in
           get_field_value() above

=cut
sub get_column_confs_from_object
{
  my $config = shift;
  my $user_role = shift;
  my $object = shift;

  my $table = $object->table();

  my @column_confs = ();

  for my $conf (@{$config->{class_info}->{$table}->{field_info_list}}) {
    my $field_db_column = $conf->{source} || $conf->{name};

    next unless $object->has_column($field_db_column);

    if ($conf->{admin_only}) {
      next unless defined $user_role && $user_role eq 'admin';
    }

    push @column_confs, $conf;
  }

  if (!@column_confs) {
    for my $column_name ($object->columns()) {
      next if $column_name eq 'created_stamp';
      if ($column_name =~ /(.*)_id$/) {
        next if $1 eq $table;
      }
      push @column_confs, { name => $column_name };
    }
  }

  return @column_confs;
}

1;
