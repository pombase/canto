package PomCur::Track::OntologyLookup;

=head1 NAME

PomCur::Track::OntologyLookup - Lookup/search methods for ontologies

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::GOLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

with 'PomCur::Configurable';
with 'PomCur::Track::TrackLookup';

=head2 web_service_lookup

 Usage   : my $lookup = PomCur::Track::OntologyLookup->new(...);
           my $result =
             $lookup->web_service_lookup($c, $search_type,
                                         $ontology_name, $search_string);
 Function: Return matching ontology terms
 Args    : $c - the Catalyst object
           $ontology_name - the ontology to search
           $search_string - the text to use when searching
 Returns : for search_type "term", returns [ { match => 'description ...' }, ...
=cut
sub web_service_lookup
{
  my $self = shift;
  my %args = @_;

  my $ontology_name = $args{ontology_name};
  my $search_string = $args{search_string};
  my $max_results = $args{max_results};
  my $include_definition = $args{include_definition};
  my $include_children = $args{include_children};

  my @ret_list = ();

  my $schema = $self->schema();
  my $rs = $schema->resultset('Cvterm')->
    search({
      name => { like => "$search_string%" }
    });

  while (defined (my $cvterm = $rs->next())) {
    my %term_hash = ();

    my $dbxref = $cvterm->dbxref();
    my $db = $dbxref->db();

    $term_hash{id} = $db->name() . ':' . $dbxref->accession();
    $term_hash{name} = $cvterm->name();

    if ($include_definition) {
      $term_hash{definition} = $cvterm->definition();
    }

    if ($include_children) {


    }

    push @ret_list, \%term_hash;
  }

  return \@ret_list;
}

1;
