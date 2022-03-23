package Canto::Curs::ConditionUtil;

=head1 NAME

Canto::Curs::ConditionUtil - Code for conditions in annotations

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::ConditionUtil

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;

use Canto::Config;

=head2 get_conditions_with_names

 Usage   : my @cond_data = get_conditions_with_names($ontology_lookup, [@conditions]);
 Function: From an array of condition names or IDS, return an array of hashes of
           condition names and IDs
 Args    : $ontology_lookup - An OntologyLookup object
           $conditions_ref  - a reference to an array of strings, each string
                              is a condition name or ontology ID.
                              eg. ['FYECO:0000137', 'rich medium']
 Return  : an array of hashes of the form:
             [ { term_id => 'FYECO:0000137', name => 'glucose rich medium' },
               { name => 'rich medium' } ]
           FYECO IDs are looked up to get the term name.  If the input element
           is not an ID, assume that condition is free text from the user to
           be fixed by curators later.

=cut

sub get_conditions_with_names
{
  my $ontology_lookup = shift;
  my $conditions = shift;

  return () unless defined $conditions;

  my @condition_data = map {
    my $ret_val;
    my $term_name_or_id = $_;
    if ($term_name_or_id =~ /^[A-Z]+:/) {
      my $result = $ontology_lookup->lookup_by_id(id => $term_name_or_id);
      if (defined $result) {
        $ret_val = {
          term_id => $term_name_or_id,
          name => $result->{name},
        };
      }
    }
    if (defined $ret_val) {
      $ret_val;
    } else {
      # some conditions are just free text if the user couldn't find the
      # appropriate FYECO term
      { name => $term_name_or_id };
    }
  } @$conditions;

  return @condition_data;
}

=head2 get_name_of_condition

 Usage   : my $cond_name = get_name_of_condition($ontology_lookup, $termid_or_name);
 Function: if the argument is an ID from the condition ontology return its name,
           otherwise just return the argument
 Args    : $ontology_lookup - An OntologyLookup object
           $termid_or_name  - an ID from the condition ontology or a free text
                              condition description

=cut

sub get_name_of_condition
{
  my $ontology_lookup = shift;
  my $termid_or_name = shift;

  eval {
    my $result = $ontology_lookup->lookup_by_id(id => $termid_or_name);
    if (defined $result) {
      $termid_or_name = $result->{name};
    } else {
      # user has made up a condition and there is no ontology term for it yet
    }
  };
  if ($@) {
    # probably not in the form DB:ACCESSION - user made it up
  }

  return $termid_or_name;
}

sub _get_id_from_name
{
  my $ontology_lookup = shift;
  my $name = shift;

  my $config = Canto::Config::get_config();

  my $result = $ontology_lookup->lookup_by_name(ontology_name => $config->{phenotype_condition_namespace},
                                                term_name => $name);
  if (defined $result) {
    return $result->{id};
  } else {
    return undef;
  }
}

=head2 get_conditions_from_names

 Usage   : my @cond_data = get_conditions_from_names($ontology_lookup, [@conditions]);
 Function: From an array of condition names, return an array of hashes of
           condition names and IDs
 Args    : $ontology_lookup - An OntologyLookup object
           $conditions_ref  - a reference to an array of strings, each string
                              is a condition name
                              eg. ['glucose rich medium', 'really cold and dark']
 Return  : an array of hashes of the form:
             [ { term_id => 'FYECO:0000137', name => 'glucose rich medium' },
               { name => 'really cold and dark' } ]
           the conditions are looked up by term name.  If the input element
           is not a term name, assume that condition is free text from the user to
           be fixed by curators later and return id without an ID

=cut

sub get_conditions_from_names
{
  my $ontology_lookup = shift;
  my $conditions = shift;

  return map {
    my %res = (name => $_);
    my $id = _get_id_from_name($ontology_lookup, $_);
    if (defined $id) {
      $res{term_id} = $id;
    }
    \%res;
  } @$conditions;
}

1;
