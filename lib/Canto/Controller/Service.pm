package Canto::Controller::Service;

=head1 NAME

Canto::Controller::Service - Web service implementations

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Controller::Service

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

use feature ':5.10';

use base 'Catalyst::Controller';

use Canto::Track;

__PACKAGE__->config->{namespace} = 'ws';

sub _ontology_results
{
  my ($c, $component_name, $search_string) = @_;

  my $config = $c->config();
  my $lookup = Canto::Track::get_adaptor($config, 'ontology');

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
  my ($c, $gene_primary_identifier, $search_string) = @_;

  $gene_primary_identifier ||= $c->req()->param('gene_primary_identifier');
  $search_string ||= $c->req()->param('term');
  my $ignore_case = $c->req()->param('ignore_case') // 0;

  if (lc $ignore_case eq 'false') {
    $ignore_case = 0;
  }

  my $config = $c->config();
  my $lookup = Canto::Track::get_adaptor($config, 'allele');

  if (!defined $lookup) {
    return [];
  }

  my $max_results = $c->req()->param('max_results') || 10;

  return $lookup->lookup(gene_primary_identifier => $gene_primary_identifier,
                         search_string => $search_string,
                         ignore_case => $ignore_case,
                         max_results => $max_results);
}

# provide /ws/person/name/Some%20Name => [{ details }, { details}] and
# /ws/person/email/some@emailaddress.com => { details }
sub _person_results
{
  my ($c, $search_type, $search_string) = @_;

  my $config = $c->config();

  my $lookup = Canto::Track::get_adaptor($config, 'person');

  my @results = $lookup->lookup($search_type, $search_string);

  if ($search_type eq 'name') {
    return \@results;
  } else {
    return $results[0];
  }
}

sub lookup : Local
{
  my $self = shift;
  my $c = shift;
  my $type_name = shift;

  my $results;

  my %dispatch = (
    allele => \&_allele_results,
    ontology => \&_ontology_results,
    person => \&_person_results,
  );

  my $res_sub = $dispatch{$type_name};

  if (defined $res_sub) {
    $results = $res_sub->($c, @_);
  } else {
    $results = { error => "unknown lookup type: $type_name" };
  }

  $c->stash->{json_data} = $results;

  $c->forward('View::JSON');
}

sub canto_config : Local
{
  my $self = shift;
  my $c = shift;
  my $config_key = shift;

  my $config = $c->config();

  my $allowed_keys = $config->{config_service}->{allowed_keys};

  if ($allowed_keys->{$config_key}) {
    my $key_config = $config->{$config_key};
    if (defined $key_config) {
      $c->stash->{json_data} = $key_config;
    } else {
      $c->stash->{json_data} = {
        status => 'error',
        message => qq(no config for key "$config_key")
      };
      $c->response->status(400);
    }
  } else {
    $c->stash->{json_data} = {
      status => 'error',
      message => qq(config key "$config_key" not allowed for this service),
    };
    $c->response->status(403);
  }

  $c->forward('View::JSON');
}

1;
