package PomCur::Controller::Search;

=head1 NAME

PomCur::Controller::Search - Actions for searching

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Controller::Search

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use perl5i::2;
use base 'Catalyst::Controller';

=head2 list

 Function: Search for objects of the given type that match the search text.
           The text much match one the configured index_fields (which defaults
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
  my $class_info = $config->class_info($c)->{$type};

  my @search_fields = @{$class_info->{search_fields}};
  my @search = map { { $_ => $search_term } } @search_fields;
  $c->stash()->{list_search_term} = $search_term;
  $c->stash()->{list_search_constraint} = [@search];

  my $model_name = $c->req()->param('model');
  $c->forward("/view/list/$type",
              {
                model => $model_name
              });
}

1;
