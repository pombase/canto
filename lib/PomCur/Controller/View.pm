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

use Lingua::EN::Inflect::Number qw(to_PL);

=head2 get_object_by_id_or_name

 Function: Find and return the object given a database id or display name.
           The database id (eg. biosample_id) is checked first.

=cut
sub get_object_by_id_or_name
{
  my $c = shift;
  my $type = shift;
  my $object_key = shift;

  my $st = $c->stash;
  my $schema = $c->schema();

  my $class_name = $schema->class_name_of_table($type);

  if ($object_key =~ /^\d+$/) {
    return $schema->find_with_type($class_name, $object_key);
  } else {
    # try looking up by display name
    my $class_info = $c->config()->{class_info}->{$type};
    if (defined $class_info) {
      if (defined $class_info->{display_field}) {
        return $schema->find_with_type($class_name,
                                       $class_info->{display_field} =>
                                         $object_key);
      }
    }
  }

  return undef;
}

=head2 object

 Function: Render details about an object (about a row in a table)
 Args    : $type - the object class from the URL
           $object_key - the id or primary key of an object to render

=cut
sub object : Local
{
  my ($self, $c, $type, $object_key) = @_;

  my $st = $c->stash;

  eval {
    $st->{title} = "Details for $type $object_key";
    $st->{template} = 'view/object/generic.mhtml';

    $st->{type} = $type;

    my $object = get_object_by_id_or_name($c, $type, $object_key);

    $st->{object} = $object;

    my $object_id = PomCur::DB::id_of_object($object);
    my $template_path = $c->path_to("root", "view", "object", "$type.mhtml");

    if (defined $template_path->stat()) {
      $c->stash()->{template} = "view/object/$type.mhtml";
    } else {
      $c->stash()->{template} = "view/object/generic.mhtml";
    }
  };
  if ($@ || !defined $st->{object}) {
    $c->stash->{error} = qq(No object type "$type" and key = $object_key - $@);
    $c->forward('/front');
  }
}

=head2 list

 Function: Render a list of all objects of a given type
 Args    : $type - the object class from the URL

=cut
sub list : Local
{
  my ($self, $c, $type) = @_;

  my $st = $c->stash;
  my $schema = $c->schema();

  eval {
    $st->{title} = 'List of all ' . to_PL($type);
    $st->{template} = 'view/list_page.mhtml';
    $st->{type} = $type;

    my $class_name = $schema->class_name_of_table($type);
    my $class_info = $c->config()->{class_info}->{$type};

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
        $order_by = \@order_by_fields;
      }
    }

    my $params = { order_by => $order_by };

    $st->{rs} = $schema->resultset($class_name)->search(undef, $params);

    $st->{page} = $c->req->param('page') || 1;
    $st->{numrows} = $c->req->param('numrows') || 20;
  };
  if ($@) {
    $c->stash->{error} = qq(No objects with type: $type - $@);
    $c->forward('/front');
  }

}

sub _get_order_by_field
{
  my $self = shift;
  my $c = shift;
  my $type = shift;

  my $class_info = $c->config()->{class_info}->{$type};

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
      $order_by = \@order_by_fields;
    }
  }

  return $order_by;
}

=head2 report

 Function: Display a report, configuration from the config file
 Args    : $report_name - the report name, used to find the configuration

=cut
sub report : Local
{
  my ($self, $c, $report_name) = @_;

  my $st = $c->stash;
  my $schema = $c->schema();

  eval {
    my $report_conf = $c->config()->{reports}->{$report_name};

    $st->{title} = $report_conf->{description};
    $st->{template} = 'view/rstable.mhtml';

    my $type = $report_conf->{object_type};

    $st->{type} = $type;

    my $class_name = $schema->class_name_of_table($type);
    my $params = { order_by => $self->_get_order_by_field($c, $type) };

    my $prefetch_conf = $report_conf->{prefetch};

    if (defined $prefetch_conf) {
      $params->{prefetch} = eval "$prefetch_conf";
    }

    $st->{rs} = $schema->resultset($class_name)->search({ }, $params);
    $st->{column_confs} = $report_conf->{columns};

    $st->{page} = $c->req->param('page') || 1;
    $st->{numrows} = $c->req->param('numrows') || 20;
  };
  if ($@) {
    $c->stash->{error} = qq(Can't display report for: $report_name - $@);
    $c->forward('/front');
  }
}

=head2 list_collection

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
