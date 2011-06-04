package PomCur::Controller::View;

=head1 NAME

PomCur::Controller::View - controller to handler /view/... requests

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Controller::View

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
use warnings;
use base 'Catalyst::Controller';

use PomCur::WebUtil;

use Lingua::EN::Inflect::Number qw(to_PL);

=head2 get_object_by_id_or_name

 Function: Find and return the object given a database id or display name.
           The database id (eg. biosample_id) is checked first.

=cut
sub get_object_by_id_or_name
{
  my $c = shift;
  my $class_info = shift;
  my $object_key = shift;

  my $st = $c->stash;
  my $schema = $c->schema();

  my $table = $class_info->{source};

  my $class_name = $schema->class_name_of_table($table);

  my $search;

  if ($object_key =~ /^\d+$/) {
    $search = { $table . "_id", $object_key };
  } else {
    # try looking up by display name
    if (defined $class_info->{display_field}) {
      $search = { $class_info->{display_field}, $object_key };
    }
  }

  my $rs = _get_list_rs($c, $search, $class_info);

  my @column_confs =
    PomCur::WebUtil::get_column_confs($c, $rs, $class_info);

  $rs = PomCur::WebUtil::process_rs_options($rs, [@column_confs]);

  return $rs->first();
}

sub _eval_format
{
  my $object = shift;
  my $eval_string = shift;
  my $failures_ref = shift;

  my $val = eval $eval_string;

  if ($@) {
    push @{$failures_ref}, $@;
  }

  return $val;
}

sub _make_title
{
  my $c = shift;
  my $object = shift;
  my $class_info = shift;

  my $type = $object->table();

  my $class_display_name = $class_info->{class_display_name} || $type;
  my $object_display_key;

  my $class_display_field = $class_info->{display_field};
  if (defined $class_display_field) {
    ($object_display_key) =
      PomCur::WebUtil::get_field_value($c, $object, $class_info,
                                       $class_display_field);
  } else {
    my $object_id_field = $type . '_id';
    $object_display_key = $object->$object_id_field();
  }

  my $title_format = $class_info->{object_title_format};

  if (defined $title_format) {
    my $title = $title_format;

    $title =~ s/\@\@DISPLAY_FIELD\@\@/$object_display_key/g;

    my @failures = ();
    $title =~ s/\@\@(\$[^@]+)\@\@/_eval_format($object, $1, \@failures)/eg;

    if (@failures) {
      for my $failure (@failures) {
        warn "eval failure: $failure";
      }
      # fall through
    } else {
      return $title;
    }
  }

  return "Details for $class_display_name $object_display_key";
}

=head2 object

 Function: Render details about an object (about a row in a table)
 Args    : $type - the object class from the URL
           $object_key - the id or primary key of an object to render

=cut
sub object : Local
{
  my ($self, $c, $config_name, $object_key) = @_;

  my $st = $c->stash;

  my $class_info = $c->config()->class_info($c)->{$config_name};
  $st->{class_info} = $class_info;

  my $table = $class_info->{source};

  eval {
    my $object = get_object_by_id_or_name($c, $class_info, $object_key);

    $st->{title} = _make_title($c, $object, $class_info);
    $st->{template} = 'view/object/generic.mhtml';

    $st->{type} = $table;
    $st->{object} = $object;

    my $model_name = $c->req()->param('model');

    my $object_id = PomCur::DB::id_of_object($object);
    my $template_path = $c->path_to("root", "view", "object", $model_name,
                                    "$table.mhtml");

    if (defined $template_path->stat()) {
      $c->stash()->{template} = "view/object/$model_name/$table.mhtml";
    } else {
      $c->stash()->{template} = "view/object/generic.mhtml";
    }
  };
  if ($@ || !defined $st->{object}) {
    $c->stash->{error} =
      qq(Cannot display object with type "$table" and key = $object_key - $@);
    $c->forward('/front');
  }
}

=head2 order_list_rs

 Usage   : order_list_rs($c, $rs, $class_info);
 Function: add an appropriate order_by option to a ResultSet, based on the
           configuration
 Args    : $c - the Catalyst object
           $rs - the ResultSet
           $class_info - the class information from the config file for this
                         ResultSet
 Returns : none, modifies $rs

=cut
sub order_list_rs
{
  my $c = shift;
  my $rs = shift;
  my $class_info = shift;

  my $table = $class_info->{source};
  my $params = { order_by => _get_order_by_field($c, $table) };

  if (defined $class_info->{constraint}) {
    my $constraint = '(' . $class_info->{constraint} . ')';
    $params->{where} = \$constraint;
  }

  return $rs->search({}, $params);
}

=head2 _get_list_rs

 Usage   : my $rs = _get_list_rs($c, $search, $class_info)
 Function: Return a ResultSet for the table given by $class_info
 Args    : $c - the Catalyst object
           $search - an options hashref to pass to the DBIx::Class search()
                     method
           $class_info - the class information from the config file used
                         to choose the table to query
 Returns :

=cut
sub _get_list_rs
{
  my $c = shift;
  my $search = shift;
  my $class_info = shift;

  my $schema = $c->schema();

  my $table = $class_info->{source};
  my $class_name = $schema->class_name_of_table($table);

  my $rs = $schema->resultset($class_name)->search($search);

  return order_list_rs($c, $rs, $class_info);
}

=head2 list

 Function: Render a list of all objects of a given type
 Args    : $type - the object class from the URL

=cut
sub list : Local
{
  my ($self, $c, $config_name) = @_;

  my $st = $c->stash;

  eval {
    $st->{template} = 'view/list_page.mhtml';

    my $config = $c->config();
    $st->{config_name} = $config_name;

    my $search = $st->{list_search_constraint};
    $st->{title} = 'List of ';

    my $class_info = $c->config()->class_info($c)->{$config_name};

    if (!defined $class_info) {
      die "no such configuration: $config_name\n";
    }

    if (defined $class_info->{extends}) {
      $st->{title} .= $class_info->{display_name};
    } else {
      my $plural_name = to_PL($class_info->{display_name});
      $st->{title} .= "all $plural_name";
    }

    my $rs = _get_list_rs($c, $search, $class_info);
    $st->{rs} = $rs;

    $st->{page} = $c->req->param('page') || 1;
    $st->{numrows} = $c->req->param('numrows') || 20;
  };
  if ($@) {
    $c->stash->{error} = qq(No objects with type: $config_name - $@);
    $c->forward('/front');
  }

}

sub _get_order_by_field
{
  my $c = shift;
  my $type = shift;

  my $class_info = $c->config()->class_info($c)->{$type};

  # default: order by id
  my $order_by = $type . '_id';

  if (defined $class_info) {
    my @order_by_fields;
    if (defined $class_info->{order_by}) {
      if (ref $class_info->{order_by}) {
        @order_by_fields = @{$class_info->{order_by}};
      } else {
        push @order_by_fields, $class_info->{order_by};
      }
    } else {
      if (defined $class_info->{display_field}) {
        push @order_by_fields, $class_info->{display_field};
      }
    }

    if (@order_by_fields) {
      my $field_infos = $class_info->{field_infos};
      $order_by = [map {
        if (defined $field_infos->{$_}) {
          my $source = $field_infos->{$_}->{source};
          if (defined $source) {
            if (ref $source) {
              die "can't use reference as order_by field for $type.$_";
            } else {
              $source;
            }
          } else {
            $_;
          }
        }
      } @order_by_fields];
      $order_by = \@order_by_fields;
    }
  }

  return $order_by;
}

=head2 collection

 Function: Render a collection from an object of a given type
 Args    : $type - the object class from the URL
           $object_id - the id of an object
           $collection_name - the collection/relation to render

=cut
sub collection : Local
{
  my ($self, $c) = @_;

  my ($type, $object_id, $collection_name) = @{$c->req->captures()};

  my $st = $c->stash;
  my $schema = $c->schema();

  $st->{title} = "List view of $collection_name for $type with id $object_id";
  $st->{template} = 'view/collection.mhtml';
  $st->{type} = $type;
  my $class_name = $schema->class_name_of_table($type);
  my $object =
    $schema->find_with_type($class_name, "${type}_id" => $object_id);

  $st->{object} = $object;
  $st->{collection_name} = $collection_name;
}

1;
