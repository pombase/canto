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

sub _ontology_results
{
  my ($c, $component_name, $search_string) = @_;

  my $config = $c->config();
  my $lookup = PomCur::Track::get_adaptor($config, 'ontology');

  my $max_results = $c->req()->param('max_results') || 15;

  my $component_config = $config->{annotation_types}->{$component_name};

  my $ontology_name;

  if (defined $component_config) {
    $ontology_name = $component_config->{namespace};
  } else {
    # allow looking up using the ontology name for those ontologies
    # that aren't configured as annotation types
    $ontology_name = $component_name;
  }

  $search_string ||= $c->req()->param('term');

  my $include_definition = $c->req()->param('def');
  my $include_children = $c->req()->param('children');
  my $include_exact_synonyms = $c->req()->param('exact_synonyms');

  my $results =
    $lookup->lookup(ontology_name => $ontology_name,
                    search_string => $search_string,
                    max_results => $max_results,
                    include_definition => $include_definition,
                    include_children => $include_children,
                    include_exact_synonyms => $include_exact_synonyms);

  map { $_->{value} = $_->{name} } @$results;

  return $results;
}

sub _allele_results
{
  my ($c, $search_string) = @_;

  $search_string ||= $c->req()->param('term');

  my $config = $c->config();
  my $lookup = PomCur::Track::get_adaptor($config, 'allele');

  if (!defined $lookup) {
    return [];
  }

  my $max_results = $c->req()->param('max_results') || 10;

  return $lookup->lookup(search_string => $search_string,
                         max_results => $max_results);
}

sub lookup : Local
{
  my $self = shift;
  my $c = shift;
  my $type_name = shift;

  my $results;

  if ($type_name eq 'allele') {
    $results = _allele_results($c, @_);
  } else {
    $results = _ontology_results($c, @_);
  }

  $c->stash->{json_data} = $results;

  $c->forward('View::JSON');
}

1;
