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
             PomCur::WebUtil::get_field_value($c, $object, $field_name);
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
           $ref_display_key - the display key of the referenced object
                              (or undef)

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
  my $field_name = shift;

  my $type = $object->table();

  if ($field_name eq "${type}_id") {
    return ($object->$field_name(), 'table_id', undef);
  }

  my $class_infos = $c->config()->class_info($c);
  my $col_conf = $class_infos->{$type}->{field_infos}->{$field_name};

  if (!defined $col_conf) {
    if ($object->can($field_name)) {
      return ($object->$field_name(), 'method', undef);
    } else {
      croak "no field_info configured for field '$field_name' of $type\n";
    }
  }

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
        return ($object->get_column($field_name), 'attribute', undef);
      } else {
        use Data::Dumper;
        die "source not understood: ", Dumper([$col_conf->{source}]), "\n";
      }
    }
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

sub process_rs_options
{
  my $rs = shift;
  my $column_confs = shift;

  my @column_options = ();

  for my $conf (@$column_confs) {
    my $source = $conf->{source};

    next unless defined $source;
    next unless ref $source eq 'HASH' && defined $source->{sql};

    push @column_options, { $conf->{name}, \"($source->{sql})" };
  }

  return $rs->search(undef, { '+columns' => [@column_options] });
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
sub get_column_confs_from_rs
{
  my $c = shift;
  my $schema = $c->schema();
  my $config = $c->config();
  my $user_role = shift;
  my $rs = shift;

  my $table = PomCur::DB::table_name_of_class($rs->result_class());

  my @column_confs = ();

  for my $conf (@{$config->class_info($c)->{$table}->{field_info_list}}) {
    my $field_db_column = $conf->{source} || $conf->{name};

    if ($schema->column_type($conf, $table) eq 'collection') {
      next;
    }

    if ($conf->{admin_only}) {
      next unless defined $user_role && $user_role eq 'admin';
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

1;
