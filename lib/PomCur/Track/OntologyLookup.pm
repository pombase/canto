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

sub _make_term_hash
{
  my $cvterm = shift;
  my $include_definition = shift;
  my $include_children = shift;

  my $cv = $cvterm->cv();

  my %term_hash = ();

  $term_hash{id} = $cvterm->db_accession();
  $term_hash{name} = $cvterm->name();

  if ($include_definition) {
    $term_hash{definition} = $cvterm->definition();
  }

  if ($include_children) {
    @{$term_hash{children}} = ();

    my @child_cvterms = $cvterm->cvterm_relationship_objects()
      ->search_related('subject')->all();

    for my $child_cvterm (@child_cvterms) {
      if ($child_cvterm->cv()->name() eq $cv->name()) {
        push @{$term_hash{children}}, {_make_term_hash($child_cvterm, 0, 0)};
      }
    }
  }

  return %term_hash;
}

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
  my $rs;

  my $cv = $schema->find_with_type('Cv', { name => $ontology_name });

  if ($search_string =~ /^([^:]+):(.*)/) {
    my $db_name = $1;
    my $db_accession = $2;

    my $where =
      "dbxref_id = (SELECT dbxref_id FROM dbxref, db
                     WHERE dbxref.db_id = db.db_id AND db.name = ?
                       AND dbxref.accession = ?)
                   AND cv_id = ?";

    $rs = $schema->resultset('Cvterm')->
      search_literal($where, $db_name, $db_accession, $cv->cv_id(),
                     { rows => $max_results });
  } else {
    $rs = $schema->resultset('Cvterm')->
      search({ name => { like => "$search_string%" },
               cv_id => $cv->cv_id() },
             { rows => $max_results,
               order_by => { -asc => 'length(name)' } });
  }

  while (defined (my $cvterm = $rs->next())) {
    my %term_hash =
      _make_term_hash($cvterm, $include_definition, $include_children);

    push @ret_list, \%term_hash;
  }

  return \@ret_list;
}

1;
