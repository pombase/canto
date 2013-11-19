package Canto::Controller::Search;

=head1 NAME

Canto::Controller::Search - Actions for searching

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Controller::Search

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
use base 'Catalyst::Controller';

=head2 list

 Function: Search for objects of the given type that match the search text.
           The text much match one the configured search_fields (which defaults
           to the display_name).  Then forward to the list display code to view
           the results.
 Args    : $type - the object class from the URL
           $search_text - the text to match.

=cut
sub type : Local
{
  my ($self, $c, $type, $search_term) = @_;

  $search_term //= $c->req()->param('search-term');

  my $schema = $c->schema();
  my $config = $c->config();
  my $model_name = $c->request()->param('model');
  my $class_info = $config->class_info($model_name)->{$type};

  my @search_fields = map {
    if (exists $class_info->{field_infos}->{$_}->{source}) {
      $class_info->{field_infos}->{$_}->{source};
    } else {
      $_;
    }
  } @{$class_info->{search_fields}};

  my $dbh = $schema->storage()->dbh();

  $search_term =~ s/\s+$//;
  $search_term =~ s/^\s+//;

  my $quoted_search_term = lc $dbh->quote($search_term);

  $quoted_search_term =~ s/\*/\%/g;

  my @search = map { { "lower($_)" => { like => \$quoted_search_term } } } @search_fields;

  $c->stash()->{list_search_term} = $search_term;
  $c->stash()->{list_search_constraint} = [@search];

  $c->forward("/view/list/$type",
              {
                model => $model_name
              });
}

1;
