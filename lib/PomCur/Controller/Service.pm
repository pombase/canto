package PomCur::Controller::Service;

=head1 NAME

PomCur::Controller::Service - Web service implementations

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Controller::Service

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

use base 'Catalyst::Controller';

use PomCur::Track;

__PACKAGE__->config->{namespace} = 'ws';

sub lookup : Local
{
  my ($self, $c, $type_name, $ontology_name, $search_string) = @_;

  my $config = $c->config();
  my $lookup = PomCur::Track::get_adaptor($config, $type_name);

  $search_string ||= $c->req()->param('term');

  my $max_results = $c->req()->param('max_results') || 10;
  my $include_definition = $c->req()->param('def');
  my $include_children = $c->req()->param('children');

  $c->stash->{json_data} =
    $lookup->web_service_lookup(ontology_name => $ontology_name,
                                search_string => $search_string,
                                max_results => $max_results,
                                include_definition => $include_definition,
                                include_children => $include_children);
  $c->forward('View::JSON');
}

1;
